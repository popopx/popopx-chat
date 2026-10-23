{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StrictData #-}
{-# LANGUAGE TemplateHaskell #-}

module Popopx.Messaging.PopopxName
  ( PopopxNameInfo (..),
    PopopxDomain (..),
    PopopxTLD (..),
    PopopxNameType (..),
    fullDomainName,
    LabelHash (..),
    labelHash,
    boundedNonSpace,
    shortNameInfoStr,
  )
where

import Control.Applicative (optional, (<|>))
import Crypto.Hash (Digest, hash)
import Crypto.Hash.Algorithms (Keccak_256)
import qualified Data.Aeson.TH as J
import qualified Data.Attoparsec.ByteString.Char8 as A
import qualified Data.Attoparsec.Text as AT
import qualified Data.ByteArray as BA
import qualified Data.ByteArray.Encoding as BAE
import Data.ByteString.Char8 (ByteString)
import qualified Data.ByteString.Char8 as B
import Data.Char (isDigit)
import Data.Functor (($>))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeLatin1, encodeUtf8)
import Popopx.Messaging.Agent.Store.DB (FromField (..), ToField (..), fromTextField_)
import Popopx.Messaging.Encoding (Encoding (..))
import Popopx.Messaging.Encoding.String
import Popopx.Messaging.Parsers (defaultJSON, dropPrefix, enumJSON)
import Popopx.Messaging.Util (eitherToMaybe, safeDecodeUtf8, (<$?>))

data PopopxNameInfo = PopopxNameInfo
  { nameType :: PopopxNameType,
    nameDomain :: PopopxDomain
  }
  deriving (Eq, Show)

data PopopxDomain = PopopxDomain
  { nameTLD :: PopopxTLD,
    domain :: Text,
    subDomain :: [Text] -- parent to child: ["b", "a"] for a.b.domain.popopx
  }
  deriving (Eq, Show)

data PopopxTLD = TLDPopopx | TLDTesting | TLDWeb
  deriving (Eq, Show)

data PopopxNameType = NTPublicGroup | NTContact
  deriving (Eq, Show)

instance StrEncoding PopopxNameType where
  strEncode = \case
    NTPublicGroup -> "#"
    NTContact -> "@"
  strP = A.char '#' $> NTPublicGroup <|> A.char '@' $> NTContact

nameLabelP :: AT.Parser Text
nameLabelP = do
  label <- T.intercalate "-" <$> AT.takeWhile1 (\c -> isNameLetter c || isDigit c) `AT.sepBy1` AT.char '-'
  -- DNS label limit: each dot-separated component is at most 63 bytes (labels
  -- are ASCII, so character count == byte count)
  if T.length label > 63 then fail "name label exceeds 63 bytes" else pure label
  where
    -- ASCII letters only. SNRC contracts hash byte sequences via keccak; ENS
    -- uses UTS-46 + Punycode for IDN, which we do not implement. Admitting
    -- Cyrillic / Greek / etc. via Data.Char.isAlpha would (a) make namehash
    -- diverge from any IDN-aware registrar and (b) allow homograph spoofing
    -- (Cyrillic а vs ASCII a hash to different on-chain records).
    isNameLetter c = c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z'

-- | The registry's key for a label: 32 bytes, as labelOf takes it.
newtype LabelHash = LabelHash ByteString
  deriving (Eq, Show)

-- | keccak-256 of the lowercased label, as the registry keys it.
labelHash :: Text -> LabelHash
labelHash label = LabelHash $ BA.convert (hash (encodeUtf8 (T.toLower label)) :: Digest Keccak_256)

instance StrEncoding LabelHash where
  strEncode (LabelHash h) = '[' `B.cons` (BAE.convertToBase BAE.Base16 h `B.snoc` ']')
  strP = do
    h <- BAE.convertFromBase BAE.Base16 <$?> (A.char '[' *> A.takeWhile (/= ']') <* A.char ']')
    if B.length h == 32 then pure $ LabelHash h else fail "bad LabelHash"

-- | Cap the name at 253 bytes (DNS full-domain limit)
boundedNonSpace :: A.Parser ByteString
boundedNonSpace = do
  bs <- A.scan (0 :: Int) $ \i c ->
    if i <= 253 && not (A.isSpace c) then Just (i + 1) else Nothing
  if B.null bs
    then fail "expected non-empty name token"
    else if B.length bs > 253 then fail "name exceeds 253 bytes" else pure bs

instance StrEncoding PopopxNameInfo where
  strEncode PopopxNameInfo {nameType, nameDomain} =
    strEncode nameType <> strEncode nameDomain
  strP = optional "popopx:/name" *> ((strP >>= infoP) <|> infoP NTPublicGroup)
    where
      infoP NTPublicGroup = PopopxNameInfo NTPublicGroup <$> (strP <|> bareName)
      infoP NTContact = PopopxNameInfo NTContact <$> strP
      bareName = parseBare . safeDecodeUtf8 <$?> boundedNonSpace
      parseBare s = (\name -> PopopxDomain TLDPopopx (T.toLower name) []) <$> AT.parseOnly (nameLabelP <* AT.endOfInput) s

instance StrEncoding PopopxDomain where
  strEncode = encodeUtf8 . fullDomainName
  strP = parseDomain . safeDecodeUtf8 <$?> boundedNonSpace
    where
      parseDomain s = AT.parseOnly (nameLabelP `AT.sepBy1` AT.char '.' <* AT.endOfInput) s >>= mkDomain
      mkDomain labels = case reverse lowered of
        [] -> Left "empty name"
        [_] -> Left "domain requires TLD"
        "popopx" : name : sub -> Right (PopopxDomain TLDPopopx name sub)
        "testing" : name : sub -> Right (PopopxDomain TLDTesting name sub)
        _ -> Right (PopopxDomain TLDWeb (T.intercalate "." lowered) [])
        where
          lowered = map T.toLower labels

instance Encoding PopopxDomain where
  smpEncode = strEncode
  smpP = strP

fullDomainName :: PopopxDomain -> Text
fullDomainName PopopxDomain {nameTLD, domain, subDomain} = T.intercalate "." (reverse subDomain ++ [domain]) <> decodeLatin1 (strEncode nameTLD)

instance StrEncoding PopopxTLD where
  strEncode = \case
    TLDPopopx -> ".popopx"
    TLDTesting -> ".testing"
    TLDWeb -> ""
  strP =
    ".popopx" $> TLDPopopx <|> ".testing" $> TLDTesting <|> pure TLDWeb

shortNameInfoStr :: PopopxNameInfo -> Text
shortNameInfoStr = \case
  PopopxNameInfo {nameType = NTPublicGroup, nameDomain = PopopxDomain {nameTLD = TLDPopopx, domain, subDomain = []}} -> "#" <> domain
  info -> pfx <> fullDomainName (nameDomain info)
    where
      pfx = case nameType info of
        NTPublicGroup -> "#"
        NTContact -> "@"

instance ToField PopopxDomain where toField = toField . decodeLatin1 . strEncode

instance FromField PopopxDomain where fromField = fromTextField_ (eitherToMaybe . strDecode . encodeUtf8)

$(J.deriveJSON (enumJSON $ dropPrefix "TLD") ''PopopxTLD)

$(J.deriveJSON (enumJSON $ dropPrefix "NT") ''PopopxNameType)

$(J.deriveJSON defaultJSON ''PopopxDomain)

$(J.deriveJSON defaultJSON ''PopopxNameInfo)
