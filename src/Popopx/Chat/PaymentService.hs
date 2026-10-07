-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE TemplateHaskell #-}

module Popopx.Chat.PaymentService
  ( ServiceInvoice (..),
    ServicePayment (..),
    module Popopx.Chat.PaymentService.Types,
  ) where

import qualified Data.Aeson.TH as JQ
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Popopx.Chat.PaymentService.Types
import Popopx.Messaging.Parsers (defaultJSON, dropPrefix, taggedObjectJSON)

data ServiceInvoice = ServiceInvoice
  { invoiceId :: InvoiceId,
    price :: CurrencyAmount,
    discount :: Maybe CurrencyAmount, -- discount amount from the price
    credit :: Maybe CurrencyAmount, -- credit for upgrade
    amount :: CurrencyAmount, -- price - discount - credit
    currency :: Text,
    expiresAt :: UTCTime,
    paymentTo :: ServicePaymentDestination
  }
  deriving (Show)

data ServicePayment
  = SPApple {jws :: Text}
  | SPGoogle {token :: Text}
  | SPInvoice {invoiceId :: InvoiceId}
  | SPReceipt {receipt :: Text} -- transfer of unissued months
  deriving (Show)

$(JQ.deriveJSON defaultJSON ''ServiceInvoice)

$(JQ.deriveJSON (taggedObjectJSON $ dropPrefix "SP") ''ServicePayment)
