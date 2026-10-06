-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20241230_reports where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20241230_reports :: Query
m20241230_reports =
  [sql|
ALTER TABLE chat_items ADD COLUMN msg_content_tag TEXT;
|]

down_m20241230_reports :: Query
down_m20241230_reports =
  [sql|
ALTER TABLE chat_items DROP COLUMN msg_content_tag;
|]
