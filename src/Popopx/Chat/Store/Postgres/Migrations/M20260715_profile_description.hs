-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260715_profile_description where

import Data.Text (Text)
import qualified Data.Text as T
import Text.RawString.QQ (r)

m20260715_profile_description :: Text
m20260715_profile_description =
  T.pack
    [r|
ALTER TABLE contact_profiles ADD COLUMN description TEXT;
|]

down_m20260715_profile_description :: Text
down_m20260715_profile_description =
  T.pack
    [r|
ALTER TABLE contact_profiles DROP COLUMN description;
|]
