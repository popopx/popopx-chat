module ChatTests.DBUtils.SQLite where

import Database.SQLite.Simple (Query)
import Popopx.Messaging.Agent.Store.SQLite.DB
import Popopx.Messaging.TMap (TMap)

data TestParams = TestParams
  { tmpPath :: FilePath,
    portBase :: Int,
    printOutput :: Bool,
    chatQueryStats :: TMap Query SlowQueryStats,
    agentQueryStats :: TMap Query SlowQueryStats
  }
