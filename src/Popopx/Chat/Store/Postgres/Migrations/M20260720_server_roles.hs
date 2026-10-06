-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260720_server_roles where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260720_server_roles :: Text
m20260720_server_roles =
  [r|
ALTER TABLE protocol_servers ADD COLUMN role_storage SMALLINT;
ALTER TABLE protocol_servers ADD COLUMN role_proxy SMALLINT;
ALTER TABLE protocol_servers ADD COLUMN role_names SMALLINT;
|]

down_m20260720_server_roles :: Text
down_m20260720_server_roles =
  [r|
ALTER TABLE protocol_servers DROP COLUMN role_storage;
ALTER TABLE protocol_servers DROP COLUMN role_proxy;
ALTER TABLE protocol_servers DROP COLUMN role_names;
|]
