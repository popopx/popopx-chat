-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20220224_messages_fks where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20220224_messages_fks :: Query
m20220224_messages_fks =
  [sql|
ALTER TABLE messages ADD COLUMN connection_id INTEGER DEFAULT NULL REFERENCES connections ON DELETE CASCADE;
ALTER TABLE messages ADD COLUMN group_id INTEGER DEFAULT NULL REFERENCES groups ON DELETE CASCADE;
|]
