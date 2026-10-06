-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20250801_via_group_link_uri where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20250801_via_group_link_uri :: Query
m20250801_via_group_link_uri =
  [sql|
ALTER TABLE groups ADD COLUMN via_group_link_uri BLOB;
ALTER TABLE connections ADD COLUMN via_contact_uri BLOB;
|]

down_m20250801_via_group_link_uri :: Query
down_m20250801_via_group_link_uri =
  [sql|
ALTER TABLE groups DROP COLUMN via_group_link_uri;
ALTER TABLE connections DROP COLUMN via_contact_uri;
|]
