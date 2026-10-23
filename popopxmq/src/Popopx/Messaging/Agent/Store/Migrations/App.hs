{-# LANGUAGE CPP #-}

module Popopx.Messaging.Agent.Store.Migrations.App
#if defined(dbPostgres)
  ( module Popopx.Messaging.Agent.Store.Postgres.Migrations.App,
  )
  where
import Popopx.Messaging.Agent.Store.Postgres.Migrations.App
#else
  ( module Popopx.Messaging.Agent.Store.SQLite.Migrations.App,
  )
  where
import Popopx.Messaging.Agent.Store.SQLite.Migrations.App
#endif
