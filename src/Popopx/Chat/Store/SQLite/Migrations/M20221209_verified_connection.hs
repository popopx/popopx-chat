-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221209_verified_connection where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221209_verified_connection :: Query
m20221209_verified_connection =
  [sql|
ALTER TABLE connections ADD COLUMN security_code TEXT NULL;
ALTER TABLE connections ADD COLUMN security_code_verified_at TEXT NULL;
|]
