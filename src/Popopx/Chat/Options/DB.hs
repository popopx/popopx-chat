-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE CPP #-}

module Popopx.Chat.Options.DB

#if defined(dbPostgres)
  ( module Popopx.Chat.Options.Postgres,
    FromField (..),
    ToField (..),
  )
  where
import Popopx.Chat.Options.Postgres
import Database.PostgreSQL.Simple.FromField (FromField (..))
import Database.PostgreSQL.Simple.ToField (ToField (..))

#else
  ( module Popopx.Chat.Options.SQLite,
    FromField (..),
    ToField (..),
  )
  where
import Popopx.Chat.Options.SQLite
import Database.SQLite.Simple.FromField (FromField (..))
import Database.SQLite.Simple.ToField (ToField (..))

#endif
