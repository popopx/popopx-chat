{-# LANGUAGE QuasiQuotes #-}

module Popopx.Chat.Store.SQLite.Migrations.M20261029_compute_purchases where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20261029_compute_purchases :: Query
m20261029_compute_purchases =
  [sql|
CREATE TABLE compute_purchases(
  compute_purchase_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  transaction_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  purchase_type TEXT NOT NULL,
  token_amount REAL NOT NULL DEFAULT 0,
  price_usd REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'completed',
  metadata TEXT,
  created_at TEXT NOT NULL
) STRICT;

CREATE INDEX idx_compute_purchases_user ON compute_purchases(user_id);
CREATE INDEX idx_compute_purchases_transaction ON compute_purchases(transaction_id);

CREATE TABLE compute_balance(
  user_id INTEGER NOT NULL REFERENCES users ON DELETE CASCADE,
  balance REAL NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id)
) STRICT;
|]

down_m20261029_compute_purchases :: Query
down_m20261029_compute_purchases =
  [sql|
DROP TABLE compute_balance;
DROP INDEX idx_compute_purchases_transaction;
DROP INDEX idx_compute_purchases_user;
DROP TABLE compute_purchases;
|]
