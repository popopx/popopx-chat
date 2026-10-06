-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20251007_connections_sync where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

-- should_sync should be set manually when required
m20251007_connections_sync :: Query
m20251007_connections_sync =
  [sql|
CREATE TABLE connections_sync(
  connections_sync_id INTEGER PRIMARY KEY AUTOINCREMENT,
  should_sync INTEGER NOT NULL DEFAULT 0,
  last_sync_ts TEXT
);

INSERT INTO connections_sync (connections_sync_id, should_sync, last_sync_ts) VALUES (1, 1, NULL);
|]

down_m20251007_connections_sync :: Query
down_m20251007_connections_sync =
  [sql|
DROP TABLE connections_sync;
|]
