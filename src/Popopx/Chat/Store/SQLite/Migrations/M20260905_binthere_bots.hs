-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20260905_binthere_bots where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20260905_binthere_bots :: Query
m20260905_binthere_bots =
  [sql|
CREATE TABLE binthere_bots (
  bot_id INTEGER PRIMARY KEY AUTOINCREMENT,
  bot_address TEXT NOT NULL UNIQUE,
  bot_name TEXT,
  bot_type TEXT NOT NULL DEFAULT 'binthere',
  enabled INTEGER NOT NULL DEFAULT 1,
  usage_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
|]

down_m20260905_binthere_bots :: Query
down_m20260905_binthere_bots =
  [sql|
DROP TABLE IF EXISTS binthere_bots;
|]
