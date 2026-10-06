-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20230827_file_encryption where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20230827_file_encryption :: Query
m20230827_file_encryption =
  [sql|
ALTER TABLE files ADD COLUMN file_crypto_key BLOB;
ALTER TABLE files ADD COLUMN file_crypto_nonce BLOB;
|]

down_m20230827_file_encryption :: Query
down_m20230827_file_encryption =
  [sql|
ALTER TABLE files DROP COLUMN file_crypto_key;
ALTER TABLE files DROP COLUMN file_crypto_nonce;
|]
