{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Messaging.Server.MsgStore
  ( MsgLogRecord (..),
  ) where

import Popopx.Messaging.Encoding.String
import Popopx.Messaging.Protocol (Message (..), RecipientId)

data MsgLogRecord = MLRv3 RecipientId Message

instance StrEncoding MsgLogRecord where
  strEncode (MLRv3 rId msg) = strEncode (Str "v3", rId, msg)
  strP = "v3 " *> (MLRv3 <$> strP_ <*> strP)
