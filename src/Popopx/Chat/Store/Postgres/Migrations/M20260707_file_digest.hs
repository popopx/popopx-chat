-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260707_file_digest where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260707_file_digest :: Text
m20260707_file_digest =
  [r|
ALTER TABLE files ADD COLUMN file_digest BYTEA;
|]

down_m20260707_file_digest :: Text
down_m20260707_file_digest =
  [r|
ALTER TABLE files DROP COLUMN file_digest;
|]
