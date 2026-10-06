-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230903_connections_to_subscribe where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230903_connections_to_subscribe :: Query
m20230903_connections_to_subscribe =
  [sql|
ALTER TABLE connections ADD COLUMN to_subscribe INTEGER DEFAULT 0 NOT NULL;
CREATE INDEX idx_connections_to_subscribe ON connections(to_subscribe);
|]

down_m20230903_connections_to_subscribe :: Query
down_m20230903_connections_to_subscribe =
  [sql|
DROP INDEX idx_connections_to_subscribe;
ALTER TABLE connections DROP COLUMN to_subscribe;
|]
