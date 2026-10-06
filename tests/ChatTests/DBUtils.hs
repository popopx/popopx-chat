-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE CPP #-}

module ChatTests.DBUtils

#if defined(dbPostgres)
  ( module ChatTests.DBUtils.Postgres,
  )
  where
import ChatTests.DBUtils.Postgres
#else
  ( module ChatTests.DBUtils.SQLite,
  )
  where
import ChatTests.DBUtils.SQLite
#endif
