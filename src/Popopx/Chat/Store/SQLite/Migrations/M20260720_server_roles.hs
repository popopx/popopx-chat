-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20260720_server_roles where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20260720_server_roles :: Query
m20260720_server_roles =
  [sql|
ALTER TABLE protocol_servers ADD COLUMN role_storage INTEGER;
ALTER TABLE protocol_servers ADD COLUMN role_proxy INTEGER;
ALTER TABLE protocol_servers ADD COLUMN role_names INTEGER;
|]

down_m20260720_server_roles :: Query
down_m20260720_server_roles =
  [sql|
ALTER TABLE protocol_servers DROP COLUMN role_storage;
ALTER TABLE protocol_servers DROP COLUMN role_proxy;
ALTER TABLE protocol_servers DROP COLUMN role_names;
|]
