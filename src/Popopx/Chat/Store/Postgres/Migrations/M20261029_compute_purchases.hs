{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.Postgres.Migrations.M20261029_compute_purchases where

import Data.Text (Text)
import Text.RawString.QQ (r)

m20261029_compute_purchases :: Text
m20261029_compute_purchases =
  [r|
CREATE TABLE compute_purchases(
  compute_purchase_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users ON DELETE CASCADE,
  transaction_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  purchase_type TEXT NOT NULL,
  token_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  price_usd DOUBLE PRECISION NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'completed',
  metadata TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX idx_compute_purchases_user ON compute_purchases(user_id);
CREATE INDEX idx_compute_purchases_transaction ON compute_purchases(transaction_id);

CREATE TABLE compute_balance(
  user_id BIGINT NOT NULL REFERENCES users ON DELETE CASCADE,
  balance DOUBLE PRECISION NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id)
);
|]

down_m20261029_compute_purchases :: Text
down_m20261029_compute_purchases =
  [r|
DROP TABLE compute_balance;
DROP INDEX idx_compute_purchases_transaction;
DROP INDEX idx_compute_purchases_user;
DROP TABLE compute_purchases;
|]
