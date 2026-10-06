-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20240510_chat_items_via_proxy where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20240510_chat_items_via_proxy :: Query
m20240510_chat_items_via_proxy =
  [sql|
ALTER TABLE chat_items ADD COLUMN via_proxy INTEGER;
ALTER TABLE group_snd_item_statuses ADD COLUMN via_proxy INTEGER;
|]

down_m20240510_chat_items_via_proxy :: Query
down_m20240510_chat_items_via_proxy =
  [sql|
ALTER TABLE chat_items DROP COLUMN via_proxy;
ALTER TABLE group_snd_item_statuses DROP COLUMN via_proxy;
|]
