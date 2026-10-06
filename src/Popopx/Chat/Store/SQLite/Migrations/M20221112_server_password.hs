-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221112_server_password where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221112_server_password :: Query
m20221112_server_password =
  [sql|
ALTER TABLE smp_servers ADD COLUMN basic_auth TEXT;
|]
