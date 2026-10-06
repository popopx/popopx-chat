-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230328_files_protocol where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230328_files_protocol :: Query
m20230328_files_protocol =
  [sql|
ALTER TABLE files ADD COLUMN protocol TEXT NOT NULL DEFAULT 'smp';
|]

down_m20230328_files_protocol :: Query
down_m20230328_files_protocol =
  [sql|
ALTER TABLE files DROP COLUMN protocol;
|]
