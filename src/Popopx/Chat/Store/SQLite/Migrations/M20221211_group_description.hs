-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221211_group_description where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221211_group_description :: Query
m20221211_group_description =
  [sql|
ALTER TABLE group_profiles ADD COLUMN description TEXT NULL;
|]
