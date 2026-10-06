-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20231214_item_content_tag where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20231214_item_content_tag :: Query
m20231214_item_content_tag =
  [sql|
ALTER TABLE chat_items ADD COLUMN item_content_tag TEXT;
|]

down_m20231214_item_content_tag :: Query
down_m20231214_item_content_tag =
  [sql|
ALTER TABLE chat_items DROP COLUMN item_content_tag;
|]
