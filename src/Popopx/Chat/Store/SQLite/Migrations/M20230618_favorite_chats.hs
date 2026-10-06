-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230618_favorite_chats where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230618_favorite_chats :: Query
m20230618_favorite_chats =
  [sql|
ALTER TABLE contacts ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0;
ALTER TABLE groups ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0;
|]

down_m20230618_favorite_chats :: Query
down_m20230618_favorite_chats =
  [sql|
ALTER TABLE contacts DROP COLUMN favorite;
ALTER TABLE groups DROP COLUMN favorite;
|]
