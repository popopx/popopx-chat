-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20260923_preferences_json where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20260923_preferences_json :: Query
m20260923_preferences_json =
  [sql|
ALTER TABLE contact_profiles ADD COLUMN preferences_json TEXT;
ALTER TABLE group_profiles ADD COLUMN preferences_json TEXT;
|]

down_m20260923_preferences_json :: Query
down_m20260923_preferences_json =
  [sql|
ALTER TABLE group_profiles DROP COLUMN preferences_json;
ALTER TABLE contact_profiles DROP COLUMN preferences_json;
|]
