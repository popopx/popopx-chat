-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20220321_chat_item_edited where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20220321_chat_item_edited :: Query
m20220321_chat_item_edited =
  [sql|
ALTER TABLE chat_items ADD COLUMN item_edited INTEGER; -- 1 for edited
|]
