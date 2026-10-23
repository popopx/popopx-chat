{-# LANGUAGE CPP #-}

module Popopx.Messaging.Agent.Store.Interface
#if defined(dbPostgres)
  ( module Popopx.Messaging.Agent.Store.Postgres,
  )
  where
import Popopx.Messaging.Agent.Store.Postgres
#else
  ( module Popopx.Messaging.Agent.Store.SQLite,
  )
  where
import Popopx.Messaging.Agent.Store.SQLite
#endif
