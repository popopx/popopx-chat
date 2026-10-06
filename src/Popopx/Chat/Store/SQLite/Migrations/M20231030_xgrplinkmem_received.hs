-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20231030_xgrplinkmem_received where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20231030_xgrplinkmem_received :: Query
m20231030_xgrplinkmem_received =
  [sql|
ALTER TABLE group_members ADD COLUMN xgrplinkmem_received INTEGER NOT NULL DEFAULT 0;
|]

down_m20231030_xgrplinkmem_received :: Query
down_m20231030_xgrplinkmem_received =
  [sql|
ALTER TABLE group_members DROP COLUMN xgrplinkmem_received;
|]
