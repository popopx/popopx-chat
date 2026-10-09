{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20261009_binthere_bar_flag where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20261009_binthere_bar_flag :: Query
m20261009_binthere_bar_flag =
  [sql|
ALTER TABLE chat_items ADD COLUMN burn_after_read INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT exists idx_chat_items_burn_after_read ON chat_items (user_id, burn_after_read, timed_delete_at);
|]

down_m20261009_binthere_bar_flag :: Query
down_m20261009_binthere_bar_flag =
  [sql|
SELECT 1;
|]
