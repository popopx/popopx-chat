-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20251017_chat_tags_cascade where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20251017_chat_tags_cascade :: Query
m20251017_chat_tags_cascade =
  [sql|
PRAGMA writable_schema=1;

UPDATE sqlite_master
SET sql = replace(sql, 'user_id INTEGER REFERENCES users', 'user_id INTEGER REFERENCES users ON DELETE CASCADE')
WHERE name = 'chat_tags' AND type = 'table';

PRAGMA writable_schema=RESET;
|]

down_m20251017_chat_tags_cascade :: Query
down_m20251017_chat_tags_cascade =
  [sql|
PRAGMA writable_schema=1;

UPDATE sqlite_master
SET sql = replace(sql, 'user_id INTEGER REFERENCES users ON DELETE CASCADE', 'user_id INTEGER REFERENCES users')
WHERE name = 'chat_tags' AND type = 'table';

PRAGMA writable_schema=RESET;
|]
