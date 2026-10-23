{-# LANGUAGE OverloadedStrings #-}

module Popopx.FileTransfer.Server.Store.Postgres.Config
  ( PostgresFileStoreCfg (..),
    defaultXFTPDBOpts,
  )
where

import Popopx.Messaging.Agent.Store.Postgres.Options (DBOpts (..))
import Popopx.Messaging.Agent.Store.Shared (MigrationConfirmation)

data PostgresFileStoreCfg = PostgresFileStoreCfg
  { dbOpts :: DBOpts,
    dbStoreLogPath :: Maybe FilePath,
    confirmMigrations :: MigrationConfirmation
  }

defaultXFTPDBOpts :: DBOpts
defaultXFTPDBOpts =
  DBOpts
    { connstr = "postgresql://xftp@/xftp_server_store",
      schema = "xftp_server",
      poolSize = 10,
      createSchema = False
    }
