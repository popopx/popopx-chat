-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221004_idx_msg_deliveries_message_id where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221004_idx_msg_deliveries_message_id :: Query
m20221004_idx_msg_deliveries_message_id =
  [sql|
CREATE INDEX idx_msg_deliveries_message_id ON msg_deliveries(message_id);
|]
