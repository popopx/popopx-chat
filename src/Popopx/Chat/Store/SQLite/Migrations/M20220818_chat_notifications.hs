-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20220818_chat_notifications where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20220818_chat_notifications :: Query
m20220818_chat_notifications =
  [sql|
ALTER TABLE contacts ADD COLUMN enable_ntfs INTEGER;

ALTER TABLE groups ADD COLUMN enable_ntfs INTEGER;
|]
