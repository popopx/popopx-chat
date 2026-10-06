-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20220302_profile_images where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20220302_profile_images :: Query
m20220302_profile_images =
  [sql|
    ALTER TABLE contact_profiles ADD COLUMN image TEXT;
    ALTER TABLE group_profiles ADD COLUMN image TEXT;
|]
