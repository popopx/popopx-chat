-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260530_client_services where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260530_client_services :: Text
m20260530_client_services =
  [r|
ALTER TABLE users ADD COLUMN client_service SMALLINT NOT NULL DEFAULT 0;
|]

down_m20260530_client_services :: Text
down_m20260530_client_services =
  [r|
ALTER TABLE users DROP COLUMN client_service;
|]
