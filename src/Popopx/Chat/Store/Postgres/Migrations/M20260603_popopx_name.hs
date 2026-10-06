-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20260603_popopx_name where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20260603_popopx_name :: Text
m20260603_popopx_name =
  [r|
ALTER TABLE contact_profiles ADD COLUMN contact_domain TEXT;
ALTER TABLE contact_profiles ADD COLUMN contact_domain_proof TEXT;
ALTER TABLE contact_profiles ADD COLUMN contact_domain_verified SMALLINT;

ALTER TABLE group_profiles ADD COLUMN group_domain_proof TEXT;
ALTER TABLE groups ADD COLUMN group_domain_verified SMALLINT;

ALTER TABLE user_contact_links ADD COLUMN link_priv_sig_key BYTEA;

ALTER TABLE server_operators ADD COLUMN smp_role_names SMALLINT NOT NULL DEFAULT 0;
UPDATE server_operators SET smp_role_names = 1 WHERE server_operator_tag = 'popopx' OR server_operator_tag = 'flux';
|]

down_m20260603_popopx_name :: Text
down_m20260603_popopx_name =
  [r|
ALTER TABLE contact_profiles DROP COLUMN contact_domain;
ALTER TABLE contact_profiles DROP COLUMN contact_domain_proof;
ALTER TABLE contact_profiles DROP COLUMN contact_domain_verified;

ALTER TABLE group_profiles DROP COLUMN group_domain_proof;
ALTER TABLE groups DROP COLUMN group_domain_verified;

ALTER TABLE user_contact_links DROP COLUMN link_priv_sig_key;

ALTER TABLE server_operators DROP COLUMN smp_role_names;
|]
