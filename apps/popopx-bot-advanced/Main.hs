-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Concurrent.Async
import Control.Concurrent.STM
import Control.Monad
import Data.Text (Text)
import qualified Data.Text as T
import Popopx.Chat.Bot
import Popopx.Chat.Controller
import Popopx.Chat.Core
import Popopx.Chat.Messages
import Popopx.Chat.Messages.CIContent
import Popopx.Chat.Options
import Popopx.Chat.Terminal (terminalChatConfig)
import Popopx.Chat.Types
import Popopx.Messaging.Util (tshow)
import System.Directory (getAppUserDataDirectory)
import Text.Read

main :: IO ()
main = do
  opts <- welcomeGetOpts
  popopxChatCore terminalChatConfig opts mySquaringBot

welcomeGetOpts :: IO ChatOpts
welcomeGetOpts = do
  appDir <- getAppUserDataDirectory "popopx"
  opts@ChatOpts {coreOptions} <- getChatOpts appDir "popopx_bot"
  putStrLn $ "POPOPX Chat Bot v" ++ versionNumber
  printDbOpts coreOptions
  pure opts

welcomeMessage :: Text
welcomeMessage = "Hello! I am a simple squaring bot.\nIf you send me a number, I will calculate its square"

mySquaringBot :: User -> ChatController -> IO ()
mySquaringBot _user cc = do
  initializeBotAddress cc
  race_ (forever $ void getLine) . forever $ do
    (_, evt) <- atomically . readTBQueue $ outputQ cc
    case evt of
      Right (CEvtContactConnected _ contact _) -> do
        contactConnected contact
        sendMessage cc contact welcomeMessage
      Right CEvtNewChatItems {chatItems = (AChatItem _ SMDRcv (DirectChat contact) ChatItem {content = mc@CIRcvMsgContent {}}) : _} -> do
        let msg = ciContentToText mc
            number_ = readMaybe (T.unpack msg) :: Maybe Integer
        sendMessage cc contact $ case number_ of
          Just n -> msg <> " * " <> msg <> " = " <> tshow (n * n)
          _ -> "\"" <> msg <> "\" is not a number"
      _ -> pure ()
  where
    contactConnected Contact {localDisplayName} = putStrLn $ T.unpack localDisplayName <> " connected"
