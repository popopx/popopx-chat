-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221001_shared_msg_id_indices where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221001_shared_msg_id_indices :: Query
m20221001_shared_msg_id_indices =
  [sql|
DROP INDEX idx_messages_group_shared_msg_id;

CREATE UNIQUE INDEX idx_chat_items_direct_shared_msg_id ON chat_items(
  user_id,
  contact_id,
  shared_msg_id
);

CREATE UNIQUE INDEX idx_chat_items_group_shared_msg_id ON chat_items(
  user_id,
  group_id,
  group_member_id,
  shared_msg_id
);
|]
