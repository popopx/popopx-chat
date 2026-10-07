-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}

module Popopx.Chat.Files where

import Popopx.Chat.Controller
import Popopx.Messaging.Util (ifM)
import System.FilePath (combine, makeValid, splitExtensions, takeFileName)
import UnliftIO.Directory (doesDirectoryExist, doesFileExist, getHomeDirectory, getTemporaryDirectory)

safeFileNameStr :: String -> String
safeFileNameStr = notDots . makeValid . takeFileName
  where
    notDots n = if n == "." || n == ".." then "_" else n

uniqueCombine :: FilePath -> String -> IO FilePath
uniqueCombine fPath fName = tryCombine (0 :: Int)
  where
    tryCombine n =
      let (name, ext) = splitExtensions $ safeFileNameStr fName
          suffix = if n == 0 then "" else "_" <> show n
          f = fPath `combine` (name <> suffix <> ext)
       in ifM (doesFileExist f) (tryCombine $ n + 1) (pure f)

getChatTempDirectory :: CM' FilePath
getChatTempDirectory = chatReadVar' tempDirectory >>= maybe getTemporaryDirectory pure

getDefaultFilesFolder :: CM' FilePath
getDefaultFilesFolder = do
  dir <- (`combine` "Downloads") <$> getHomeDirectory
  ifM (doesDirectoryExist dir) (pure dir) getChatTempDirectory
