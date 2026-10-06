-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20240226_users_restrict where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20240226_users_restrict :: Query
m20240226_users_restrict =
  [sql|
PRAGMA writable_schema=1;

UPDATE sqlite_master
SET sql = replace(sql, 'ON DELETE CASCADE', 'ON DELETE RESTRICT')
WHERE name = 'users' AND type = 'table';

PRAGMA writable_schema=RESET;
|]

down_m20240226_users_restrict :: Query
down_m20240226_users_restrict =
  [sql|
PRAGMA writable_schema=1;

UPDATE sqlite_master
SET sql = replace(sql, 'ON DELETE RESTRICT', 'ON DELETE CASCADE')
WHERE name = 'users' AND type = 'table';

PRAGMA writable_schema=RESET;
|]
