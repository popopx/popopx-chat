-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221019_unread_chat where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221019_unread_chat :: Query
m20221019_unread_chat =
  [sql|
PRAGMA ignore_check_constraints=ON;

ALTER TABLE contacts ADD COLUMN unread_chat INTEGER DEFAULT 0 CHECK (unread_chat NOT NULL);
UPDATE contacts SET unread_chat = 0;
ALTER TABLE groups ADD COLUMN unread_chat INTEGER DEFAULT 0 CHECK (unread_chat NOT NULL);
UPDATE groups SET unread_chat = 0;

PRAGMA ignore_check_constraints=OFF;
|]

