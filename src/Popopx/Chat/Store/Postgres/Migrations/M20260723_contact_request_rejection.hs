-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260723_contact_request_rejection where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260723_contact_request_rejection :: Text
m20260723_contact_request_rejection =
  [r|
ALTER TABLE contact_requests ADD COLUMN rejection_supported SMALLINT NOT NULL DEFAULT 0;
|]

down_m20260723_contact_request_rejection :: Text
down_m20260723_contact_request_rejection =
  [r|
ALTER TABLE contact_requests DROP COLUMN rejection_supported;
|]
