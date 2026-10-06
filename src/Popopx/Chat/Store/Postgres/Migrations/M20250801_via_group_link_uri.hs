-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20250801_via_group_link_uri where

import Data.Text (Text)
import qualified Data.Text as T
import Text.RawString.QQ (r)

m20250801_via_group_link_uri :: Text
m20250801_via_group_link_uri =
  T.pack
    [r|
ALTER TABLE groups ADD COLUMN via_group_link_uri BYTEA;
ALTER TABLE connections ADD COLUMN via_contact_uri BYTEA;
|]

down_m20250801_via_group_link_uri :: Text
down_m20250801_via_group_link_uri =
  T.pack
    [r|
ALTER TABLE groups DROP COLUMN via_group_link_uri;
ALTER TABLE connections DROP COLUMN via_contact_uri;
|]
