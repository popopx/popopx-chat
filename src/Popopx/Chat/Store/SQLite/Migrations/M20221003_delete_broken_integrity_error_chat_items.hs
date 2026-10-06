-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221003_delete_broken_integrity_error_chat_items where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221003_delete_broken_integrity_error_chat_items :: Query
m20221003_delete_broken_integrity_error_chat_items =
  [sql|
DELETE FROM chat_items WHERE item_content LIKE '%{"rcvIntegrityError":{%';
|]
