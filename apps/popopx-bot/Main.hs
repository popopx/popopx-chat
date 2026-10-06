-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE NamedFieldPuns #-}

module Main where

import Popopx.Chat.Bot
import Popopx.Chat.Controller (versionNumber)
import Popopx.Chat.Core
import Popopx.Chat.Options
import Popopx.Chat.Terminal (terminalChatConfig)
import System.Directory (getAppUserDataDirectory)
import Text.Read

main :: IO ()
main = do
  opts <- welcomeGetOpts
  popopxChatCore terminalChatConfig opts $
    chatBotRepl welcomeMessage $ \_contact msg ->
      pure $ case readMaybe msg :: Maybe Integer of
        Just n -> msg <> " * " <> msg <> " = " <> show (n * n)
        _ -> "\"" <> msg <> "\" is not a number"

welcomeMessage :: String
welcomeMessage = "Hello! I am a simple squaring bot.\nIf you send me a number, I will calculate its square"

welcomeGetOpts :: IO ChatOpts
welcomeGetOpts = do
  appDir <- getAppUserDataDirectory "popopx"
  opts@ChatOpts {coreOptions} <- getChatOpts appDir "popopx_bot"
  putStrLn $ "POPOPX Chat Bot v" ++ versionNumber
  printDbOpts coreOptions
  pure opts
