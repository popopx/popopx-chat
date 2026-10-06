-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20260906_bot_directory where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20260906_bot_directory :: Query
m20260906_bot_directory =
  [sql|
ALTER TABLE binthere_bots ADD COLUMN description TEXT;
ALTER TABLE binthere_bots ADD COLUMN icon_url TEXT;
ALTER TABLE binthere_bots ADD COLUMN token_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE binthere_bots ADD COLUMN pricing_unit TEXT;
ALTER TABLE binthere_bots ADD COLUMN pricing_amount INTEGER NOT NULL DEFAULT 0;
|]

down_m20260906_bot_directory :: Query
down_m20260906_bot_directory =
  [sql|
SELECT 1;
|]
