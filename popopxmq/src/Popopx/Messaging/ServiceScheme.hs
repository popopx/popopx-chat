{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Messaging.ServiceScheme
  ( ServiceScheme (..),
    SrvLoc (..),
    popopxChat,
  ) where

import Control.Applicative ((<|>))
import qualified Data.Attoparsec.ByteString.Char8 as A
import qualified Data.ByteString.Char8 as B
import Data.Functor (($>))
import Network.Socket (ServiceName)
import Popopx.Messaging.Encoding.String (StrEncoding (..))
import Popopx.Messaging.Transport.Client (TransportHost (..))

data ServiceScheme = SSPopopx | SSAppServer SrvLoc
  deriving (Eq, Show)

instance StrEncoding ServiceScheme where
  strEncode = \case
    SSPopopx -> "popopx:"
    SSAppServer srv -> "https://" <> strEncode srv
  strP =
    "popopx:" $> SSPopopx
      <|> "https://" *> (SSAppServer <$> strP)

data SrvLoc = SrvLoc TransportHost ServiceName
  deriving (Eq, Ord, Show)

instance StrEncoding SrvLoc where
  strEncode (SrvLoc host port)
    | null port = strEncode host
    | otherwise = h <> B.pack (':' : port)
    where
      h = case host of
        THIPv6 _ -> ('[' `B.cons` strEncode host) `B.snoc` ']'
        _ -> strEncode host
  strP = SrvLoc <$> strP <*> (port <|> pure "")
    where
      port = show <$> (A.char ':' *> (A.decimal :: A.Parser Int))

popopxChat :: ServiceScheme
popopxChat = SSAppServer $ SrvLoc "popopx.xyz" ""
