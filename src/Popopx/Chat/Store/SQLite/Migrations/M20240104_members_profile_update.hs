-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20240104_members_profile_update where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20240104_members_profile_update :: Query
m20240104_members_profile_update =
  [sql|
ALTER TABLE users ADD COLUMN user_member_profile_updated_at TEXT;
ALTER TABLE groups ADD COLUMN user_member_profile_sent_at TEXT;
|]

down_m20240104_members_profile_update :: Query
down_m20240104_members_profile_update =
  [sql|
ALTER TABLE groups DROP COLUMN user_member_profile_sent_at;
ALTER TABLE users DROP COLUMN user_member_profile_updated_at;
|]
