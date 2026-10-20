{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20261009_binthere_bar_flag where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20261009_binthere_bar_flag :: Text
m20261009_binthere_bar_flag =
  [r|
ALTER TABLE chat_items ADD COLUMN burn_after_read SMALLINT NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_chat_items_burn_after_read ON chat_items (user_id, burn_after_read, timed_delete_at);
|]

down_m20261009_binthere_bar_flag :: Text
down_m20261009_binthere_bar_flag =
  [r|
SELECT 1;
|]
