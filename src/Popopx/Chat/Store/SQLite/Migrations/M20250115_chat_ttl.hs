-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20250115_chat_ttl where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20250115_chat_ttl :: Query
m20250115_chat_ttl =
  [sql|
ALTER TABLE contacts ADD COLUMN chat_item_ttl INTEGER;
ALTER TABLE groups ADD COLUMN chat_item_ttl INTEGER;
ALTER TABLE groups ADD COLUMN local_alias TEXT DEFAULT '';
|]

down_m20250115_chat_ttl :: Query
down_m20250115_chat_ttl =
  [sql|
ALTER TABLE contacts DROP COLUMN chat_item_ttl;
ALTER TABLE groups DROP COLUMN chat_item_ttl;
ALTER TABLE groups DROP COLUMN local_alias;
|]
