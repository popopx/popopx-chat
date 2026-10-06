-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221130_delete_item_deleted where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221130_delete_item_deleted :: Query
m20221130_delete_item_deleted =
  [sql|
DELETE FROM chat_items WHERE item_deleted = 1; -- clean up legacy not fully deleted group chat items
|]
