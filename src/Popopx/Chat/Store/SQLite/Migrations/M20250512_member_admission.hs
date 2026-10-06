-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20250512_member_admission where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20250512_member_admission :: Query
m20250512_member_admission =
  [sql|
ALTER TABLE group_profiles ADD COLUMN member_admission TEXT;
|]

down_m20250512_member_admission :: Query
down_m20250512_member_admission =
  [sql|
ALTER TABLE group_profiles DROP COLUMN member_admission;
|]
