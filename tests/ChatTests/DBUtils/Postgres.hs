-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

module ChatTests.DBUtils.Postgres where

data TestParams = TestParams
  { tmpPath :: FilePath,
    printOutput :: Bool
  }
