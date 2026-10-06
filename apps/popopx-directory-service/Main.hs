-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}

module Main where

import Directory.Options
import Directory.Service
import Directory.Store
import Directory.Store.Migrate
import Popopx.Chat.Terminal (terminalChatConfig)

main :: IO ()
main = do
  opts@DirectoryOpts {directoryLog, migrateDirectoryLog, runCLI} <- welcomeGetOpts
  case migrateDirectoryLog of
    Just cmd -> migrate cmd opts terminalChatConfig
    Nothing -> do
      st <- openDirectoryLog directoryLog
      if runCLI
        then directoryServiceCLI st opts
        else directoryService st opts terminalChatConfig
  where
    migrate = \case
      MLCheck -> checkDirectoryLog
      MLImport -> importDirectoryLogToDB
      MLExport -> exportDBToDirectoryLog
      MLListing -> saveGroupListingFiles
