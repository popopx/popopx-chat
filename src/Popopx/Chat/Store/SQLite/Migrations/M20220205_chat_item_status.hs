-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20220205_chat_item_status where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20220205_chat_item_status :: Query
m20220205_chat_item_status =
  [sql|
PRAGMA ignore_check_constraints=ON;

ALTER TABLE chat_items ADD COLUMN item_status TEXT CHECK (item_status NOT NULL);

UPDATE chat_items SET item_status = 'rcv_read' WHERE item_sent = 0;

UPDATE chat_items SET item_status = 'snd_sent' WHERE item_sent = 1;

PRAGMA ignore_check_constraints=OFF;
|]
