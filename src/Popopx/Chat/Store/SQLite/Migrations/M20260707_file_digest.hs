-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20260707_file_digest where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20260707_file_digest :: Query
m20260707_file_digest =
  [sql|
ALTER TABLE files ADD COLUMN file_digest BLOB;
|]

down_m20260707_file_digest :: Query
down_m20260707_file_digest =
  [sql|
ALTER TABLE files DROP COLUMN file_digest;
|]
