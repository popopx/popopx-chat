-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230519_item_deleted_ts where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230519_item_deleted_ts :: Query
m20230519_item_deleted_ts =
  [sql|
ALTER TABLE chat_items ADD COLUMN item_deleted_ts TEXT;
|]

down_m20230519_item_deleted_ts :: Query
down_m20230519_item_deleted_ts =
  [sql|
ALTER TABLE chat_items DROP COLUMN item_deleted_ts;
|]
