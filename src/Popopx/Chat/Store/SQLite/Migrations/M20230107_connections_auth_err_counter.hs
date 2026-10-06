-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230107_connections_auth_err_counter where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230107_connections_auth_err_counter :: Query
m20230107_connections_auth_err_counter =
  [sql|
PRAGMA ignore_check_constraints=ON;

ALTER TABLE connections ADD COLUMN auth_err_counter INTEGER DEFAULT 0 CHECK (auth_err_counter NOT NULL);
UPDATE connections SET auth_err_counter = 0;

PRAGMA ignore_check_constraints=OFF;
|]
