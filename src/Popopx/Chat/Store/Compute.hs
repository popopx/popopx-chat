{-# LANGUAGE CPP #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}

module Popopx.Chat.Store.Compute
  ( ComputePurchase (..),
    PurchaseType (..),
    PurchaseStatus (..),
    ComputeBalance (..),
    getComputeBalance,
    setComputeBalance,
    recordComputePurchase,
    getComputePurchases,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Aeson as A
import qualified Data.Aeson.TH as J
import Popopx.Chat.Store.Shared (insertedRowId)
import qualified Popopx.Messaging.Agent.Store.DB as DB
import Popopx.Messaging.Parsers (defaultJSON)
import Popopx.Messaging.Util (maybeFirstRow)

#if defined(dbPostgres)
import Database.PostgreSQL.Simple (Only (..), (:.) (..))
import Database.PostgreSQL.Simple.SqlQQ (sql)
#else
import Database.SQLite.Simple (Only (..), (:.) (..))
import Database.SQLite.Simple.QQ (sql)
#endif

data PurchaseType = TokenPack | RedPacketSend | RedPacketReceive | BotUsage
  deriving (Eq, Show)

purchaseTypeToText :: PurchaseType -> Text
purchaseTypeToText TokenPack = "token_pack"
purchaseTypeToText RedPacketSend = "red_packet_send"
purchaseTypeToText RedPacketReceive = "red_packet_receive"
purchaseTypeToText BotUsage = "bot_usage"

purchaseTypeFromText :: Text -> PurchaseType
purchaseTypeFromText "token_pack" = TokenPack
purchaseTypeFromText "red_packet_send" = RedPacketSend
purchaseTypeFromText "red_packet_receive" = RedPacketReceive
purchaseTypeFromText "bot_usage" = BotUsage
purchaseTypeFromText _ = TokenPack

data PurchaseStatus = Completed | Pending | Failed | Refunded
  deriving (Eq, Show)

purchaseStatusToText :: PurchaseStatus -> Text
purchaseStatusToText Completed = "completed"
purchaseStatusToText Pending = "pending"
purchaseStatusToText Failed = "failed"
purchaseStatusToText Refunded = "refunded"

purchaseStatusFromText :: Text -> PurchaseStatus
purchaseStatusFromText "completed" = Completed
purchaseStatusFromText "pending" = Pending
purchaseStatusFromText "failed" = Failed
purchaseStatusFromText "refunded" = Refunded
purchaseStatusFromText _ = Completed

data ComputePurchase = ComputePurchase
  { computePurchaseId :: Int64,
    userId :: Int64,
    transactionId :: Text,
    productId :: Text,
    purchaseType :: PurchaseType,
    tokenAmount :: Double,
    priceUsd :: Double,
    status :: PurchaseStatus,
    metadata :: Maybe Text,
    createdAt :: Text
  }
  deriving (Eq, Show)

data ComputeBalance = ComputeBalance
  { userId :: Int64,
    balance :: Double,
    updatedAt :: Text
  }
  deriving (Eq, Show)

getComputeBalance :: DB.Connection -> Int64 -> IO (Maybe ComputeBalance)
getComputeBalance db uid =
  maybeFirstRow toComputeBalance $
    DB.query
      db
      [sql|
        SELECT user_id, balance, updated_at
        FROM compute_balance
        WHERE user_id = ?
      |]
      (Only uid)

toComputeBalance :: (Int64, Double, Text) -> ComputeBalance
toComputeBalance (uid, bal, updatedAt) = ComputeBalance {userId = uid, balance = bal, updatedAt}

setComputeBalance :: DB.Connection -> Int64 -> Double -> Text -> IO ()
setComputeBalance db uid bal updatedAt =
  DB.execute
    db
    [sql|
      INSERT INTO compute_balance (user_id, balance, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET balance = excluded.balance, updated_at = excluded.updated_at
    |]
    (uid, bal, updatedAt)

recordComputePurchase :: DB.Connection -> ComputePurchase -> IO Int64
recordComputePurchase db ComputePurchase {userId, transactionId, productId, purchaseType, tokenAmount, priceUsd, status, metadata, createdAt} = do
  DB.execute
    db
    [sql|
      INSERT INTO compute_purchases
        (user_id, transaction_id, product_id, purchase_type, token_amount, price_usd, status, metadata, created_at)
      VALUES (?,?,?,?,?,?,?,?,?)
    |]
    (userId, transactionId, productId, purchaseTypeToText purchaseType, tokenAmount, priceUsd, purchaseStatusToText status, metadata, createdAt)
  insertedRowId db

toComputePurchase :: (Int64, Int64, Text, Text, Text, Double, Double, Text, Maybe Text, Text) -> ComputePurchase
toComputePurchase (pid, uid, tid, prodId, pType, tAmt, pUsd, st, meta, createdAt) =
  ComputePurchase
    { computePurchaseId = pid,
      userId = uid,
      transactionId = tid,
      productId = prodId,
      purchaseType = purchaseTypeFromText pType,
      tokenAmount = tAmt,
      priceUsd = pUsd,
      status = purchaseStatusFromText st,
      metadata = meta,
      createdAt = createdAt
    }

getComputePurchases :: DB.Connection -> Int64 -> IO [ComputePurchase]
getComputePurchases db uid =
  map toComputePurchase
    <$> DB.query
      db
      [sql|
        SELECT compute_purchase_id, user_id, transaction_id, product_id, purchase_type, token_amount, price_usd, status, metadata, created_at
        FROM compute_purchases
        WHERE user_id = ?
        ORDER BY created_at DESC
      |]
      (Only uid)

instance A.ToJSON PurchaseType where
  toJSON = A.String . purchaseTypeToText

instance A.FromJSON PurchaseType where
  parseJSON = A.withText "PurchaseType" (pure . purchaseTypeFromText)

instance A.ToJSON PurchaseStatus where
  toJSON = A.String . purchaseStatusToText

instance A.FromJSON PurchaseStatus where
  parseJSON = A.withText "PurchaseStatus" (pure . purchaseStatusFromText)

$(J.deriveJSON defaultJSON ''ComputePurchase)
$(J.deriveJSON defaultJSON ''ComputeBalance)
