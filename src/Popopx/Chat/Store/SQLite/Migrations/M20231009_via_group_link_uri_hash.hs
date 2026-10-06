-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20231009_via_group_link_uri_hash where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20231009_via_group_link_uri_hash :: Query
m20231009_via_group_link_uri_hash =
  [sql|
CREATE INDEX idx_connections_conn_req_inv ON connections(conn_req_inv);

ALTER TABLE groups ADD COLUMN via_group_link_uri_hash BLOB;
CREATE INDEX idx_groups_via_group_link_uri_hash ON groups(via_group_link_uri_hash);
|]

down_m20231009_via_group_link_uri_hash :: Query
down_m20231009_via_group_link_uri_hash =
  [sql|
DROP INDEX idx_groups_via_group_link_uri_hash;
ALTER TABLE groups DROP COLUMN via_group_link_uri_hash;

DROP INDEX idx_connections_conn_req_inv;
|]
