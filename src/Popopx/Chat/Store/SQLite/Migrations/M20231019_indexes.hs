-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20231019_indexes where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20231019_indexes :: Query
m20231019_indexes =
  [sql|
DROP INDEX idx_connections_conn_req_inv;
CREATE INDEX idx_connections_conn_req_inv ON connections(user_id, conn_req_inv);

DROP INDEX idx_groups_via_group_link_uri_hash;
CREATE INDEX idx_groups_via_group_link_uri_hash ON groups(user_id, via_group_link_uri_hash);

DROP INDEX idx_connections_via_contact_uri_hash;
CREATE INDEX idx_connections_via_contact_uri_hash ON connections(user_id, via_contact_uri_hash);
|]

down_m20231019_indexes :: Query
down_m20231019_indexes =
  [sql|
DROP INDEX idx_connections_conn_req_inv;
CREATE INDEX idx_connections_conn_req_inv ON connections(conn_req_inv);

DROP INDEX idx_groups_via_group_link_uri_hash;
CREATE INDEX idx_groups_via_group_link_uri_hash ON groups(via_group_link_uri_hash);

DROP INDEX idx_connections_via_contact_uri_hash;
CREATE INDEX idx_connections_via_contact_uri_hash ON connections(via_contact_uri_hash);
|]
