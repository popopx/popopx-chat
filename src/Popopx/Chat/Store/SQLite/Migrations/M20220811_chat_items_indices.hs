-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20220811_chat_items_indices where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20220811_chat_items_indices :: Query
m20220811_chat_items_indices =
  [sql|
CREATE INDEX idx_chat_items_groups ON chat_items(user_id, group_id, item_ts, chat_item_id);
CREATE INDEX idx_chat_items_contacts ON chat_items(user_id, contact_id, chat_item_id);
|]
