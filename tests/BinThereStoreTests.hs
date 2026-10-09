{-# LANGUAGE CPP #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module BinThereStoreTests (binThereStoreTests) where

import Control.Exception (finally)
import Data.Int (Int64)
import Data.Text (Text)
import Popopx.Chat.Store.BinThere
import Popopx.Chat.Store.Profiles (BinThereBot (..))
import Popopx.Messaging.Agent.Store.Common (DBStore (..), withTransaction)
import Popopx.Messaging.Agent.Store.DB (TrackQueries (..))
import Popopx.Messaging.Agent.Store.Interface (DBOpts (..), closeDBStore, createDBStore)
import Popopx.Messaging.Agent.Store.Shared (MigrationConfig (..), MigrationConfirmation (..))
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))
import Test.Hspec
import UnliftIO.Temporary (withTempDirectory)

#if defined(dbPostgres)
import qualified Data.ByteString.Char8 as BC
import Data.IORef
import System.IO.Unsafe (unsafePerformIO)
import Popopx.Chat.Store.Postgres.Migrations (migrations)
#else
import Popopx.Messaging.Agent.Store.Shared (Migration (..))
#endif

binThereStoreTests :: Spec
binThereStoreTests = describe "BinThere Store" $ do
  it "creates and reads a bot by id" testCreateAndReadBotById
  it "reads a bot by address" testReadBotByAddress
  it "lists all bots" testListAllBots
  it "updates a bot" testUpdateBot
  it "deletes a bot" testDeleteBot
  it "increments usage count" testIncrementUsage
  it "returns Nothing for non-existent bot" testNonExistentBot

#if !defined(dbPostgres)
binThereMigrations :: [Migration]
binThereMigrations =
  [ Migration
      { name = "20260905_binthere_bots_full",
        up = "CREATE TABLE binthere_bots (\n  bot_id INTEGER PRIMARY KEY AUTOINCREMENT,\n  bot_address TEXT NOT NULL UNIQUE,\n  bot_name TEXT,\n  bot_type TEXT NOT NULL DEFAULT 'binthere',\n  enabled INTEGER NOT NULL DEFAULT 1,\n  usage_count INTEGER NOT NULL DEFAULT 0,\n  created_at TEXT NOT NULL DEFAULT (datetime('now')),\n  updated_at TEXT NOT NULL DEFAULT (datetime('now')),\n  description TEXT,\n  icon_url TEXT,\n  token_count INTEGER NOT NULL DEFAULT 0,\n  pricing_unit TEXT,\n  pricing_amount INTEGER NOT NULL DEFAULT 0\n);",
        down = Just "DROP TABLE IF EXISTS binthere_bots;"
      }
  ]
#endif

sampleBot :: BinThereBot
sampleBot =
  BinThereBot
    { botId = 0,
      botAddress = "binthere-test-address-123",
      botName = Just "Test Burn Bot",
      botType = "binthere",
      enabled = True,
      usageCount = 0,
      createdAt = "2026-10-09 00:00:00",
      updatedAt = "2026-10-09 00:00:00",
      description = Just "A test burn-after-read bot",
      iconUrl = Just "https://example.com/icon.png",
      tokenCount = 100,
      pricingUnit = Just "token",
      pricingAmount = 5
    }

sampleBot2 :: BinThereBot
sampleBot2 =
  BinThereBot
    { botId = 0,
      botAddress = "binthere-test-address-456",
      botName = Nothing,
      botType = "binthere",
      enabled = False,
      usageCount = 10,
      createdAt = "2026-10-09 01:00:00",
      updatedAt = "2026-10-09 01:00:00",
      description = Nothing,
      iconUrl = Nothing,
      tokenCount = 0,
      pricingUnit = Nothing,
      pricingAmount = 0
    }

withChatStore :: (DBStore -> IO a) -> IO a
#if defined(dbPostgres)
withChatStore action = do
  n <- atomicModifyIORef' chatSchemaCounter (\i -> (i + 1, i))
  Right st <- createDBStore (chatDBOpts n) migrations (MigrationConfig MCError Nothing)
  action st `finally` closeDBStore st
  where
    chatDBOpts :: Int -> DBOpts
    chatDBOpts n =
      DBOpts
        { connstr = BC.pack testDBConnstr,
          schema = "sx_chat_binthere_test_" <> BC.pack (show n),
          poolSize = 4,
          createSchema = True
        }

chatSchemaCounter :: IORef Int
chatSchemaCounter = unsafePerformIO $ newIORef 0
{-# NOINLINE chatSchemaCounter #-}

testDBConnstr :: String
testDBConnstr = "host=localhost user=postgres password=postgres dbname=popopx_test"
#else
withChatStore action = do
  createDirectoryIfMissing True "tests/tmp"
  withTempDirectory "tests/tmp" "binthere-store" $ \dir -> do
    Right st <-
      createDBStore
        (DBOpts (dir </> "binthere_test.db") [] "" False True TQOff)
        binThereMigrations
        (MigrationConfig MCError Nothing)
    action st `finally` closeDBStore st
#endif

testCreateAndReadBotById :: IO ()
testCreateAndReadBotById = withChatStore $ \st ->
  withTransaction st $ \db -> do
    botId <- createBinThereBot db sampleBot
    botId `shouldSatisfy` (> 0)
    Just bot <- getBinThereBotById db botId
    botAddress bot `shouldBe` "binthere-test-address-123"
    botName bot `shouldBe` Just "Test Burn Bot"
    botType bot `shouldBe` "binthere"
    enabled bot `shouldBe` True
    usageCount bot `shouldBe` 0
    description bot `shouldBe` Just "A test burn-after-read bot"
    iconUrl bot `shouldBe` Just "https://example.com/icon.png"
    tokenCount bot `shouldBe` 100
    pricingUnit bot `shouldBe` Just "token"
    pricingAmount bot `shouldBe` 5

testReadBotByAddress :: IO ()
testReadBotByAddress = withChatStore $ \st ->
  withTransaction st $ \db -> do
    _ <- createBinThereBot db sampleBot
    Just bot <- getBinThereBotByAddress db "binthere-test-address-123"
    botAddress bot `shouldBe` "binthere-test-address-123"
    botName bot `shouldBe` Just "Test Burn Bot"

testListAllBots :: IO ()
testListAllBots = withChatStore $ \st ->
  withTransaction st $ \db -> do
    _ <- createBinThereBot db sampleBot
    _ <- createBinThereBot db sampleBot2
    bots <- getBinThereBots db
    length bots `shouldBe` 2
    map botAddress bots `shouldContain` ["binthere-test-address-123", "binthere-test-address-456"]

testUpdateBot :: IO ()
testUpdateBot = withChatStore $ \st ->
  withTransaction st $ \db -> do
    botId <- createBinThereBot db sampleBot
    Just bot <- getBinThereBotById db botId
    let updated = bot {botName = Just "Updated Name", enabled = False, pricingAmount = 10}
    updateBinThereBot db updated
    Just bot' <- getBinThereBotById db botId
    botName bot' `shouldBe` Just "Updated Name"
    enabled bot' `shouldBe` False
    pricingAmount bot' `shouldBe` 10

testDeleteBot :: IO ()
testDeleteBot = withChatStore $ \st ->
  withTransaction st $ \db -> do
    botId <- createBinThereBot db sampleBot
    Just _ <- getBinThereBotById db botId
    deleteBinThereBot db botId
    Nothing <- getBinThereBotById db botId
    pure ()

testIncrementUsage :: IO ()
testIncrementUsage = withChatStore $ \st ->
  withTransaction st $ \db -> do
    botId <- createBinThereBot db sampleBot
    incrementBotUsage db botId
    incrementBotUsage db botId
    incrementBotUsage db botId
    Just bot <- getBinThereBotById db botId
    usageCount bot `shouldBe` 3

testNonExistentBot :: IO ()
testNonExistentBot = withChatStore $ \st ->
  withTransaction st $ \db -> do
    Nothing <- getBinThereBotById db 99999
    Nothing <- getBinThereBotByAddress db "non-existent-address"
    pure ()
