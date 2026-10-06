-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20220926_connection_alias where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20220926_connection_alias :: Query
m20220926_connection_alias =
  [sql|
PRAGMA ignore_check_constraints=ON;

ALTER TABLE connections ADD COLUMN local_alias DEFAULT '' CHECK (local_alias NOT NULL);
UPDATE connections SET local_alias = '';

PRAGMA ignore_check_constraints=OFF;
|]
