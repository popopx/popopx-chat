-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230422_profile_contact_links where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230422_profile_contact_links :: Query
m20230422_profile_contact_links =
  [sql|
ALTER TABLE contact_profiles ADD COLUMN contact_link BLOB;
|]

down_m20230422_profile_contact_links :: Query
down_m20230422_profile_contact_links =
  [sql|
ALTER TABLE contact_profiles DROP COLUMN contact_link;
|]
