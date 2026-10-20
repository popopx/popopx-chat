-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260905_binthere_bots where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260905_binthere_bots :: Text
m20260905_binthere_bots =
  [r|
CREATE TABLE binthere_bots (
  bot_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bot_address TEXT NOT NULL UNIQUE,
  bot_name TEXT,
  bot_type TEXT NOT NULL DEFAULT 'binthere',
  enabled SMALLINT NOT NULL DEFAULT 1,
  usage_count BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
|]

down_m20260905_binthere_bots :: Text
down_m20260905_binthere_bots =
  [r|
DROP TABLE IF EXISTS binthere_bots;
|]
