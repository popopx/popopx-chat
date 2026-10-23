{-# LANGUAGE CPP #-}

module Popopx.Messaging.Agent.Store.DB
#if defined(dbPostgres)
  ( module Popopx.Messaging.Agent.Store.Postgres.DB,
    FromField (..),
    ToField (..),
  )
  where
import Popopx.Messaging.Agent.Store.Postgres.DB
#else
  ( module Popopx.Messaging.Agent.Store.SQLite.DB,
    FromField (..),
    ToField (..),
  )
  where
import Popopx.Messaging.Agent.Store.SQLite.DB
#endif
