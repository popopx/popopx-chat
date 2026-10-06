-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230129_drop_chat_items_group_idx where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230129_drop_chat_items_group_idx :: Query
m20230129_drop_chat_items_group_idx =
  [sql|
DROP INDEX idx_chat_items_group_id;
|]
