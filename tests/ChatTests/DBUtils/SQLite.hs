-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

module ChatTests.DBUtils.SQLite where

import Database.SQLite.Simple (Query)
import Simplex.Messaging.Agent.Store.SQLite.DB
import Simplex.Messaging.TMap (TMap)

data TestParams = TestParams
  { tmpPath :: FilePath,
    printOutput :: Bool,
    chatQueryStats :: TMap Query SlowQueryStats,
    agentQueryStats :: TMap Query SlowQueryStats
  }
