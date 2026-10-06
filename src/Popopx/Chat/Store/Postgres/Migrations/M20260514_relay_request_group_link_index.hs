-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260514_relay_request_group_link_index where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260514_relay_request_group_link_index :: Text
m20260514_relay_request_group_link_index =
  [r|
CREATE INDEX idx_groups_relay_request_group_link
  ON groups(user_id, relay_request_group_link)
  WHERE relay_request_group_link IS NOT NULL;
|]

down_m20260514_relay_request_group_link_index :: Text
down_m20260514_relay_request_group_link_index =
  [r|
DROP INDEX idx_groups_relay_request_group_link;
|]
