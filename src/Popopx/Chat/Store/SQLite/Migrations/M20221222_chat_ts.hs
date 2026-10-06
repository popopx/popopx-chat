-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221222_chat_ts where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221222_chat_ts :: Query
m20221222_chat_ts =
  [sql|
ALTER TABLE contacts ADD COLUMN chat_ts TEXT; -- must be not NULL

ALTER TABLE groups ADD COLUMN chat_ts TEXT; -- must be not NULL
|]
