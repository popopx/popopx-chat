{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Popopx.Messaging.Protocol.Types
  ( ClientNotice (..),
  ) where

import qualified Data.Aeson.TH as J
import Data.Int (Int64)
import Popopx.Messaging.Parsers

data ClientNotice = ClientNotice
  { ttl :: Maybe Int64 -- seconds, Nothing - indefinite
  }
  deriving (Eq, Show)

$(J.deriveJSON defaultJSON ''ClientNotice)
