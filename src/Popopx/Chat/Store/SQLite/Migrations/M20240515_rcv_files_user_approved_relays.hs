-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20240515_rcv_files_user_approved_relays where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20240515_rcv_files_user_approved_relays :: Query
m20240515_rcv_files_user_approved_relays =
  [sql|
ALTER TABLE rcv_files ADD COLUMN user_approved_relays INTEGER NOT NULL DEFAULT 0;
|]

down_m20240515_rcv_files_user_approved_relays :: Query
down_m20240515_rcv_files_user_approved_relays =
  [sql|
ALTER TABLE rcv_files DROP COLUMN user_approved_relays;
|]
