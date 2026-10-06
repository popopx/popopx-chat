-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20241008_indexes where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20241008_indexes :: Query
m20241008_indexes =
  [sql|
CREATE INDEX idx_received_probes_group_member_id on received_probes(group_member_id);
|]

down_m20241008_indexes :: Query
down_m20241008_indexes =
  [sql|
DROP INDEX idx_received_probes_group_member_id;
|]
