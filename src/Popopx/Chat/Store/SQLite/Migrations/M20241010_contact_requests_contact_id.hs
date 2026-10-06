-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20241010_contact_requests_contact_id where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20241010_contact_requests_contact_id :: Query
m20241010_contact_requests_contact_id =
  [sql|
ALTER TABLE contact_requests ADD COLUMN contact_id INTEGER REFERENCES contacts ON DELETE CASCADE;

CREATE INDEX idx_contact_requests_contact_id ON contact_requests(contact_id);
|]

down_m20241010_contact_requests_contact_id :: Query
down_m20241010_contact_requests_contact_id =
  [sql|
DROP INDEX idx_contact_requests_contact_id;

ALTER TABLE contact_requests DROP COLUMN contact_id;
|]
