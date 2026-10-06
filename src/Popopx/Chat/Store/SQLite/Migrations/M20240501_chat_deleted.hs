-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20240501_chat_deleted where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20240501_chat_deleted :: Query
m20240501_chat_deleted =
  [sql|
ALTER TABLE contacts ADD COLUMN chat_deleted INTEGER NOT NULL DEFAULT 0;
|]

down_m20240501_chat_deleted :: Query
down_m20240501_chat_deleted =
  [sql|
ALTER TABLE contacts DROP COLUMN chat_deleted;
|]
