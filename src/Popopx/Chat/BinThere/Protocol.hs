{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Chat.BinThere.Protocol
  ( burnAfterReadTTL,
    isBinThereMessage,
    setBinThereDeleteAt,
  )
where

import Data.Int (Int64)
import Data.Time.Clock (UTCTime, addUTCTime, getCurrentTime)
import Data.Time.Clock (NominalDiffTime)
import qualified Popopx.Messaging.Agent.Store.DB as DB

burnAfterReadTTL :: Int
burnAfterReadTTL = 30

isBinThereMessage :: Bool -> Bool
isBinThereMessage = id

setBinThereDeleteAt :: DB.Connection -> Int64 -> IO UTCTime
setBinThereDeleteAt db itemId = do
  now <- getCurrentTime
  let deleteAt = addUTCTime (fromIntegral burnAfterReadTTL :: NominalDiffTime) now
  DB.execute
    db
    "UPDATE chat_items SET timed_ttl = ?, timed_delete_at = ? WHERE chat_item_id = ?"
    (burnAfterReadTTL, deleteAt, itemId)
  pure deleteAt
