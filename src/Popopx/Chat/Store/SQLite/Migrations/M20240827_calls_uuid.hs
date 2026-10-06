-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20240827_calls_uuid where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20240827_calls_uuid :: Query
m20240827_calls_uuid =
  [sql|
ALTER TABLE calls ADD COLUMN call_uuid TEXT NOT NULL DEFAULT "";
|]

down_m20240827_calls_uuid :: Query
down_m20240827_calls_uuid =
  [sql|
ALTER TABLE calls DROP COLUMN call_uuid;
|]
