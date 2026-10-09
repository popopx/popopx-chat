{-# LANGUAGE CPP #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeOperators #-}

module Popopx.Chat.Store.BinThere
  ( createBinThereBot,
    getBinThereBots,
    getBinThereBotById,
    getBinThereBotByAddress,
    updateBinThereBot,
    deleteBinThereBot,
    incrementBotUsage,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Popopx.Chat.Store.Profiles (BinThereBot (..))
import Popopx.Chat.Store.Shared (insertedRowId)
import Popopx.Messaging.Agent.Store.DB (BoolInt (..))
import qualified Popopx.Messaging.Agent.Store.DB as DB
import Popopx.Messaging.Util (maybeFirstRow)

#if defined(dbPostgres)
import Database.PostgreSQL.Simple (Only (..), (:.) (..))
import Database.PostgreSQL.Simple.SqlQQ (sql)
#else
import Database.SQLite.Simple (Only (..), (:.) (..))
import Database.SQLite.Simple.QQ (sql)
#endif

toBinThereBot :: (Int64, Text, Maybe Text, Text, BoolInt, Int, Text, Text) :. (Maybe Text, Maybe Text, Int, Maybe Text, Int) -> BinThereBot
toBinThereBot ((botId, botAddress, botName, botType, BI enabled, usageCount, createdAt, updatedAt) :. (description, iconUrl, tokenCount, pricingUnit, pricingAmount)) =
  BinThereBot {botId, botAddress, botName, botType, enabled, usageCount, createdAt, updatedAt, description, iconUrl, tokenCount, pricingUnit, pricingAmount}

createBinThereBot :: DB.Connection -> BinThereBot -> IO Int64
createBinThereBot db BinThereBot {botAddress, botName, botType, enabled, usageCount, createdAt, updatedAt, description, iconUrl, tokenCount, pricingUnit, pricingAmount} = do
  DB.execute
    db
    [sql|
      INSERT INTO binthere_bots
        (bot_address, bot_name, bot_type, enabled, usage_count, created_at, updated_at, description, icon_url, token_count, pricing_unit, pricing_amount)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
    |]
    ((botAddress, botName, botType, BI enabled, usageCount, createdAt, updatedAt, description, iconUrl, tokenCount) :. (pricingUnit, pricingAmount))
  insertedRowId db

binThereBotsQuery :: DB.Connection -> IO [BinThereBot]
binThereBotsQuery db =
  map toBinThereBot
    <$> DB.query_
      db
      [sql|
        SELECT bot_id, bot_address, bot_name, bot_type, enabled, usage_count, created_at, updated_at, description, icon_url, token_count, pricing_unit, pricing_amount
        FROM binthere_bots
        ORDER BY bot_id
      |]

getBinThereBots :: DB.Connection -> IO [BinThereBot]
getBinThereBots = binThereBotsQuery

getBinThereBotById :: DB.Connection -> Int64 -> IO (Maybe BinThereBot)
getBinThereBotById db botId =
  maybeFirstRow toBinThereBot $
    DB.query
      db
      [sql|
        SELECT bot_id, bot_address, bot_name, bot_type, enabled, usage_count, created_at, updated_at, description, icon_url, token_count, pricing_unit, pricing_amount
        FROM binthere_bots
        WHERE bot_id = ?
      |]
      (Only botId)

getBinThereBotByAddress :: DB.Connection -> Text -> IO (Maybe BinThereBot)
getBinThereBotByAddress db botAddress =
  maybeFirstRow toBinThereBot $
    DB.query
      db
      [sql|
        SELECT bot_id, bot_address, bot_name, bot_type, enabled, usage_count, created_at, updated_at, description, icon_url, token_count, pricing_unit, pricing_amount
        FROM binthere_bots
        WHERE bot_address = ?
      |]
      (Only botAddress)

updateBinThereBot :: DB.Connection -> BinThereBot -> IO ()
updateBinThereBot db BinThereBot {botId, botAddress, botName, botType, enabled, description, iconUrl, tokenCount, pricingUnit, pricingAmount, updatedAt} =
  DB.execute
    db
    [sql|
      UPDATE binthere_bots
      SET bot_address = ?, bot_name = ?, bot_type = ?, enabled = ?, description = ?, icon_url = ?, token_count = ?, pricing_unit = ?, pricing_amount = ?, updated_at = ?
      WHERE bot_id = ?
    |]
    ((botAddress, botName, botType, BI enabled, description, iconUrl, tokenCount, pricingUnit, pricingAmount, updatedAt) :. (Only botId))

deleteBinThereBot :: DB.Connection -> Int64 -> IO ()
deleteBinThereBot db botId =
  DB.execute db "DELETE FROM binthere_bots WHERE bot_id = ?" (Only botId)

incrementBotUsage :: DB.Connection -> Int64 -> IO ()
incrementBotUsage db botId =
  DB.execute
    db
    [sql|
      UPDATE binthere_bots
      SET usage_count = usage_count + 1, updated_at = datetime('now')
      WHERE bot_id = ?
    |]
    (Only botId)
