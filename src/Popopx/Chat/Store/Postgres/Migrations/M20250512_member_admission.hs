-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20250512_member_admission where

import Data.Text (Text)
import qualified Data.Text as T
import Text.RawString.QQ (r)

m20250512_member_admission :: Text
m20250512_member_admission =
  T.pack
    [r|
ALTER TABLE group_profiles ADD COLUMN member_admission TEXT;
|]

down_m20250512_member_admission :: Text
down_m20250512_member_admission =
  T.pack
    [r|
ALTER TABLE group_profiles DROP COLUMN member_admission;
|]
