-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260714_member_security_code where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260714_member_security_code :: Text
m20260714_member_security_code =
  [r|
ALTER TABLE group_members ADD COLUMN member_security_code TEXT;
ALTER TABLE group_members ADD COLUMN member_security_code_verified_at TIMESTAMPTZ;
|]

down_m20260714_member_security_code :: Text
down_m20260714_member_security_code =
  [r|
ALTER TABLE group_members DROP COLUMN member_security_code;
ALTER TABLE group_members DROP COLUMN member_security_code_verified_at;
|]
