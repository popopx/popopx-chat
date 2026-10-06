-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20260715_profile_description where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20260715_profile_description :: Query
m20260715_profile_description =
  [sql|
ALTER TABLE contact_profiles ADD COLUMN description TEXT;
|]

down_m20260715_profile_description :: Query
down_m20260715_profile_description =
  [sql|
ALTER TABLE contact_profiles DROP COLUMN description;
|]
