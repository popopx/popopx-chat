-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20260530_client_services where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20260530_client_services :: Query
m20260530_client_services =
  [sql|
ALTER TABLE users ADD COLUMN client_service INTEGER NOT NULL DEFAULT 0;
|]

down_m20260530_client_services :: Query
down_m20260530_client_services =
  [sql|
ALTER TABLE users DROP COLUMN client_service;
|]
