-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230814_indexes where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230814_indexes :: Query
m20230814_indexes =
  [sql|
CREATE INDEX idx_chat_items_user_id_item_status ON chat_items(user_id, item_status);
|]

down_m20230814_indexes :: Query
down_m20230814_indexes =
  [sql|
DROP INDEX idx_chat_items_user_id_item_status;
|]
