-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20251230_strict_tables where

import Data.Text (Text)
import Text.RawString.QQ (r)
import Popopx.Messaging.Agent.Store.Postgres.Migrations.M20251230_strict_tables (isValidText)

m20251230_strict_tables :: Text
m20251230_strict_tables =
  isValidText
    <> [r|
DELETE FROM calls
WHERE NOT popopx_is_valid_text(call_state);

ALTER TABLE calls ALTER COLUMN call_state TYPE TEXT USING call_state::TEXT;

DROP FUNCTION popopx_is_valid_text(BYTEA);
|]

down_m20251230_strict_tables :: Text
down_m20251230_strict_tables =
  [r|
ALTER TABLE calls ALTER COLUMN call_state TYPE BYTEA USING call_state::BYTEA;  
|]
