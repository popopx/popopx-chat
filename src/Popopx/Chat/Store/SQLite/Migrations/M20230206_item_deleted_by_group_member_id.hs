-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230206_item_deleted_by_group_member_id where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230206_item_deleted_by_group_member_id :: Query
m20230206_item_deleted_by_group_member_id =
  [sql|
ALTER TABLE chat_items ADD COLUMN item_deleted_by_group_member_id INTEGER REFERENCES group_members ON DELETE SET NULL;

CREATE INDEX idx_chat_items_item_deleted_by_group_member_id ON chat_items(item_deleted_by_group_member_id);
|]
