{-# LANGUAGE CPP #-}

module Popopx.Messaging.Agent.Store.Common
#if defined(dbPostgres)
  ( module Popopx.Messaging.Agent.Store.Postgres.Common,
  )
  where
import Popopx.Messaging.Agent.Store.Postgres.Common
#else
  ( module Popopx.Messaging.Agent.Store.SQLite.Common,
  )
  where
import Popopx.Messaging.Agent.Store.SQLite.Common
#endif
