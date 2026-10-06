-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}

module Popopx.Chat.Mobile.Badges
  ( cChatBadgeKeygen,
    cChatBadgeIssue,
    BadgeResult (..),
    BadgeIssueReq (..),
    IssuerKeyPair (..),
  )
where

import Data.Aeson (FromJSON (..), ToJSON (..))
import qualified Data.Aeson as J
import qualified Data.Aeson.TH as JQ
import qualified Data.ByteString as B
import Data.Text (Text)
import qualified Data.Text as T
import Foreign.C (CString)
import Popopx.Chat.Badges
import Popopx.Chat.Mobile.Shared (CJSONString, newCStringFromLazyBS)
import Popopx.Messaging.Crypto.BBS (BBSPublicKey, BBSSecretKey, bbsKeyGen)
import Popopx.Messaging.Parsers (defaultJSON)

-- FFI envelope for a generated issuer keypair (the BBS keypair tuple serialized with named fields)
data IssuerKeyPair = IssuerKeyPair
  { publicKey :: BBSPublicKey,
    secretKey :: BBSSecretKey
  }

data BadgeIssueReq = BadgeIssueReq
  { badgeKeyIdx :: Int,
    secretKey :: BBSSecretKey,
    request :: BadgeRequest
  }

data BadgeResult r
  = BadgeResult {result :: r}
  | BadgeError {error :: Text}

$(JQ.deriveJSON defaultJSON ''IssuerKeyPair)

$(JQ.deriveJSON defaultJSON ''BadgeIssueReq)

$(pure [])

instance ToJSON r => ToJSON (BadgeResult r) where
  toEncoding = $(JQ.mkToEncoding (defaultJSON {J.sumEncoding = J.UntaggedValue}) ''BadgeResult)
  toJSON = $(JQ.mkToJSON (defaultJSON {J.sumEncoding = J.UntaggedValue}) ''BadgeResult)

instance FromJSON r => FromJSON (BadgeResult r) where
  parseJSON = $(JQ.mkParseJSON (defaultJSON {J.sumEncoding = J.UntaggedValue}) ''BadgeResult)

cChatBadgeKeygen :: IO CJSONString
cChatBadgeKeygen =
  bbsKeyGen >>= \case
    Right (pk, sk) -> encodeResult $ BadgeResult (IssuerKeyPair pk sk)
    Left e -> encodeResult @IssuerKeyPair $ BadgeError (T.pack e)

cChatBadgeIssue :: CString -> IO CJSONString
cChatBadgeIssue cReq = do
  bs <- B.packCString cReq
  encodeResult @BadgeCredential =<< case J.eitherDecodeStrict' bs of
    Left e -> pure $ BadgeError (T.pack e)
    Right BadgeIssueReq {badgeKeyIdx, secretKey, request} ->
      either (BadgeError . T.pack) BadgeResult <$> issueBadge badgeKeyIdx secretKey (VerifiedBadgeRequest request)

encodeResult :: ToJSON r => BadgeResult r -> IO CJSONString
encodeResult = newCStringFromLazyBS . J.encode
