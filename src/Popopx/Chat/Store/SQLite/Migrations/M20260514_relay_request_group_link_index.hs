-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20260514_relay_request_group_link_index where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20260514_relay_request_group_link_index :: Query
m20260514_relay_request_group_link_index =
  [sql|
CREATE INDEX idx_groups_relay_request_group_link
  ON groups(user_id, relay_request_group_link)
  WHERE relay_request_group_link IS NOT NULL;
|]

down_m20260514_relay_request_group_link_index :: Query
down_m20260514_relay_request_group_link_index =
  [sql|
DROP INDEX idx_groups_relay_request_group_link;
|]
