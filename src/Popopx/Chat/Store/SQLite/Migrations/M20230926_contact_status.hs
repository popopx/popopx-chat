-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230926_contact_status where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230926_contact_status :: Query
m20230926_contact_status =
  [sql|
ALTER TABLE contacts ADD COLUMN contact_status TEXT NOT NULL DEFAULT 'active';
|]

down_m20230926_contact_status :: Query
down_m20230926_contact_status =
  [sql|
ALTER TABLE contacts DROP COLUMN contact_status;
|]
