-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230111_users_agent_user_id where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230111_users_agent_user_id :: Query
m20230111_users_agent_user_id =
  [sql|
PRAGMA ignore_check_constraints=ON;

ALTER TABLE users ADD COLUMN agent_user_id INTEGER CHECK (agent_user_id NOT NULL);
UPDATE users SET agent_user_id = 1;

PRAGMA ignore_check_constraints=OFF;
|]
