{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20261018_autoincrement_ids where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20261018_autoincrement_ids :: Query
m20261018_autoincrement_ids =
  [sql|
-- This migration is now a no-op.
-- SQLite automatically creates sqlite_sequence table when AUTOINCREMENT is used.
-- We don't need to manually manage it.
SELECT 1;
|]

down_m20261018_autoincrement_ids :: Query
down_m20261018_autoincrement_ids =
  [sql|
-- No-op: this migration doesn't change anything
SELECT 1;
|]
