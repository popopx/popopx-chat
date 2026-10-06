-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230420_rcv_files_to_receive where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230420_rcv_files_to_receive :: Query
m20230420_rcv_files_to_receive =
  [sql|
ALTER TABLE rcv_files ADD COLUMN to_receive INTEGER;
|]

down_m20230420_rcv_files_to_receive :: Query
down_m20230420_rcv_files_to_receive =
  [sql|
ALTER TABLE rcv_files DROP COLUMN to_receive;
|]
