-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20221029_group_link_id where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20221029_group_link_id :: Query
m20221029_group_link_id =
  [sql|
ALTER TABLE user_contact_links ADD COLUMN group_link_id BLOB;

ALTER TABLE connections ADD COLUMN group_link_id BLOB;
|]
