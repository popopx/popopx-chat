-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20220823_delete_broken_group_event_chat_items where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20220823_delete_broken_group_event_chat_items :: Query
m20220823_delete_broken_group_event_chat_items =
  [sql|
DELETE FROM chat_items WHERE item_content LIKE '%{"rcvGroupEvent":{"rcvGroupEvent":{%';
DELETE FROM chat_items WHERE item_content LIKE '%{"sndGroupEvent":{"sndGroupEvent":{%';
|]
