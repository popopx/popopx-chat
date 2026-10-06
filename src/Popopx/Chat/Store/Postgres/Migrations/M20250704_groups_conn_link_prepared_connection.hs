-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20250704_groups_conn_link_prepared_connection where

import Data.Text (Text)
import qualified Data.Text as T
import Text.RawString.QQ (r)

m20250704_groups_conn_link_prepared_connection :: Text
m20250704_groups_conn_link_prepared_connection =
  T.pack
    [r|
ALTER TABLE groups ADD COLUMN conn_link_prepared_connection SMALLINT NOT NULL DEFAULT 0;
|]

down_m20250704_groups_conn_link_prepared_connection :: Text
down_m20250704_groups_conn_link_prepared_connection =
  T.pack
    [r|
ALTER TABLE groups DROP COLUMN conn_link_prepared_connection;
|]
