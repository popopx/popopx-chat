-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221210_idxs where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221210_idxs :: Query
m20221210_idxs =
  [sql|
CREATE INDEX idx_messages_connection_id ON messages(connection_id);

CREATE INDEX idx_chat_items_group_member_id ON chat_items(group_member_id);

CREATE INDEX idx_chat_items_contact_id ON chat_items(contact_id);
|]
