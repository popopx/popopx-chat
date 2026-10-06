-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20240324_custom_data where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20240324_custom_data :: Query
m20240324_custom_data =
  [sql|
ALTER TABLE contacts ADD COLUMN custom_data BLOB;
ALTER TABLE groups ADD COLUMN custom_data BLOB;
|]

down_m20240324_custom_data :: Query
down_m20240324_custom_data =
  [sql|
ALTER TABLE contacts DROP COLUMN custom_data;
ALTER TABLE groups DROP COLUMN custom_data;
|]
