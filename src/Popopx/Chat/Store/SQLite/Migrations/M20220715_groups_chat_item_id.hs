-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20220715_groups_chat_item_id where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20220715_groups_chat_item_id :: Query
m20220715_groups_chat_item_id =
  [sql|
ALTER TABLE groups ADD COLUMN chat_item_id INTEGER DEFAULT NULL REFERENCES chat_items ON DELETE SET NULL;
|]
