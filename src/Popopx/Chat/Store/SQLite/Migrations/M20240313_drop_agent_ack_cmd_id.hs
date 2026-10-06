-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20240313_drop_agent_ack_cmd_id where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20240313_drop_agent_ack_cmd_id :: Query
m20240313_drop_agent_ack_cmd_id =
  [sql|
DROP INDEX idx_msg_deliveries_agent_ack_cmd_id;

ALTER TABLE msg_deliveries DROP COLUMN agent_ack_cmd_id;
|]

down_m20240313_drop_agent_ack_cmd_id :: Query
down_m20240313_drop_agent_ack_cmd_id =
  [sql|
ALTER TABLE msg_deliveries ADD COLUMN agent_ack_cmd_id INTEGER;

CREATE INDEX idx_msg_deliveries_agent_ack_cmd_id ON msg_deliveries(connection_id, agent_ack_cmd_id);
|]
