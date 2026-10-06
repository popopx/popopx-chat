-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Chat.Store.AppSettings where

import Control.Monad (join)
import Control.Monad.IO.Class (liftIO)
import Data.Maybe (fromMaybe)
import Popopx.Chat.AppSettings (AppSettings (..), combineAppSettings, defaultAppSettings, defaultParseAppSettings)
import Popopx.Messaging.Agent.Store.AgentStore (maybeFirstRow)
import qualified Popopx.Messaging.Agent.Store.DB as DB
import Popopx.Messaging.Util (decodeJSON, encodeJSON)

#if defined(dbPostgres)
import Database.PostgreSQL.Simple (Only (..))
#else
import Database.SQLite.Simple (Only (..))
#endif

saveAppSettings :: DB.Connection -> AppSettings -> IO ()
saveAppSettings db appSettings = do
  DB.execute_ db "DELETE FROM app_settings"
  DB.execute db "INSERT INTO app_settings (app_settings) VALUES (?)" (Only $ encodeJSON appSettings)

getAppSettings :: DB.Connection -> Maybe AppSettings -> IO AppSettings
getAppSettings db platformDefaults = do
  stored_ <- join <$> liftIO (maybeFirstRow (decodeJSON . fromOnly) $ DB.query_ db "SELECT app_settings FROM app_settings")
  pure $ combineAppSettings (fromMaybe defaultAppSettings platformDefaults) (fromMaybe defaultParseAppSettings stored_)
