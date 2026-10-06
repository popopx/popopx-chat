-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20260601_relay_sent_web_domain where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20260601_relay_sent_web_domain :: Query
m20260601_relay_sent_web_domain =
  [sql|
ALTER TABLE groups ADD COLUMN relay_sent_web_domain TEXT;
|]

down_m20260601_relay_sent_web_domain :: Query
down_m20260601_relay_sent_web_domain =
  [sql|
ALTER TABLE groups DROP COLUMN relay_sent_web_domain;
|]
