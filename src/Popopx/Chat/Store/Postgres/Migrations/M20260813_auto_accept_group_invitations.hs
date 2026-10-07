-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260813_auto_accept_group_invitations where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260813_auto_accept_group_invitations :: Text
m20260813_auto_accept_group_invitations =
  [r|
ALTER TABLE users ADD COLUMN auto_accept_group_invitations SMALLINT NOT NULL DEFAULT 0;
|]

down_m20260813_auto_accept_group_invitations :: Text
down_m20260813_auto_accept_group_invitations =
  [r|
ALTER TABLE users DROP COLUMN auto_accept_group_invitations;
|]
