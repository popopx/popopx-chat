-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221223_idx_chat_items_item_status where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221223_idx_chat_items_item_status :: Query
m20221223_idx_chat_items_item_status =
  [sql|
CREATE INDEX idx_chat_items_item_status ON chat_items(item_status);
|]
