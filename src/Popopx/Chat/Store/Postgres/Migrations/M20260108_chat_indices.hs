-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260108_chat_indices where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260108_chat_indices :: Text
m20260108_chat_indices =
  [r|
CREATE INDEX idx_chat_items_contacts_msg_content_tag_created_at ON chat_items(
  user_id,
  contact_id,
  msg_content_tag,
  created_at
);

CREATE INDEX idx_chat_items_note_folder_msg_content_tag_created_at ON chat_items(
  user_id,
  note_folder_id,
  msg_content_tag,
  created_at
);  
|]

down_m20260108_chat_indices :: Text
down_m20260108_chat_indices =
  [r|
DROP INDEX idx_chat_items_contacts_msg_content_tag_created_at;

DROP INDEX idx_chat_items_note_folder_msg_content_tag_created_at;
|]
