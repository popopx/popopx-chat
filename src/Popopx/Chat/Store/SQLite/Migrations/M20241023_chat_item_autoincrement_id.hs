-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20241023_chat_item_autoincrement_id where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20241023_chat_item_autoincrement_id :: Query
m20241023_chat_item_autoincrement_id =
    [sql|
-- This migration is now a no-op.
-- SQLite automatically creates sqlite_sequence table when AUTOINCREMENT is used.
-- We don't need to manually manage it.
SELECT 1;
|]

down_m20241023_chat_item_autoincrement_id :: Query
down_m20241023_chat_item_autoincrement_id =
    [sql|
-- No-op: this migration doesn't change anything
SELECT 1;
|]
