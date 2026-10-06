-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221025_chat_settings where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221025_chat_settings :: Query
m20221025_chat_settings =
  [sql|
PRAGMA ignore_check_constraints=ON;

ALTER TABLE group_profiles ADD COLUMN preferences TEXT;

ALTER TABLE contact_profiles ADD COLUMN preferences TEXT;

ALTER TABLE contacts ADD COLUMN user_preferences TEXT DEFAULT '{}' CHECK (user_preferences NOT NULL);
UPDATE contacts SET user_preferences = '{}';

PRAGMA ignore_check_constraints=OFF;
|]
