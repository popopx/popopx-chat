-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260906_bot_directory where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260906_bot_directory :: Text
m20260906_bot_directory =
  [r|
ALTER TABLE binthere_bots ADD COLUMN description TEXT;
ALTER TABLE binthere_bots ADD COLUMN icon_url TEXT;
ALTER TABLE binthere_bots ADD COLUMN token_count BIGINT NOT NULL DEFAULT 0;
ALTER TABLE binthere_bots ADD COLUMN pricing_unit TEXT;
ALTER TABLE binthere_bots ADD COLUMN pricing_amount BIGINT NOT NULL DEFAULT 0;
|]

down_m20260906_bot_directory :: Text
down_m20260906_bot_directory =
  [r|
SELECT 1;
|]
