{-# LANGUAGE CPP #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE PostfixOperators #-}
{-# LANGUAGE ScopedTypeVariables #-}

module BinThereIntegrationTests (binThereIntegrationTests) where

import ChatClient
import ChatTests.DBUtils
import ChatTests.Utils
import Test.Hspec hiding (it)

binThereIntegrationTests :: SpecWith TestParams
binThereIntegrationTests =
  describe "burn-after-read messages" $
    it "send BAR message with 30-second TTL" testBARMessageTTL

testBARMessageTTL :: HasCallStack => TestParams -> IO ()
testBARMessageTTL =
  testChat2 aliceProfile bobProfile $
    \alice bob -> do
      connectUsers alice bob

      -- Send a BAR message
      alice ##> "/_send @2 bar=on text secret message"
      alice <# "@bob secret message"
      bob <# "alice> secret message"

      -- The message should be marked as timed and deleted after 30 seconds
      -- In the test environment, we verify the message was sent with BAR flag
      -- The actual deletion is handled by the existing timed message infrastructure
      alice <## "timed message deleted: secret message"
      bob <## "timed message deleted: secret message"
