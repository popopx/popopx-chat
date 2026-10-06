-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20240430_ui_theme where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20240430_ui_theme :: Query
m20240430_ui_theme =
  [sql|
ALTER TABLE users ADD COLUMN ui_themes TEXT;  
ALTER TABLE contacts ADD COLUMN ui_themes TEXT;
ALTER TABLE groups ADD COLUMN ui_themes TEXT;
|]

down_m20240430_ui_theme :: Query
down_m20240430_ui_theme =
  [sql|
ALTER TABLE users DROP COLUMN ui_themes;
ALTER TABLE contacts DROP COLUMN ui_themes;
ALTER TABLE groups DROP COLUMN ui_themes;
|]
