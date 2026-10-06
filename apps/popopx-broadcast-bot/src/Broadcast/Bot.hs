-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}

module Broadcast.Bot where

import Control.Concurrent (forkIO)
import Control.Concurrent.Async
import Control.Concurrent.STM
import Control.Monad
import qualified Data.Text as T
import Broadcast.Options
import Popopx.Chat.Bot
import Popopx.Chat.Bot.KnownContacts
import Popopx.Chat.Controller
import Popopx.Chat.Core
import Popopx.Chat.Messages
import Popopx.Chat.Messages.CIContent
import Popopx.Chat.Options
import Popopx.Chat.Protocol (MsgContent (..))
import Popopx.Chat.Types
import Popopx.Messaging.Util (tshow)
import System.Directory (getAppUserDataDirectory)

welcomeGetOpts :: IO BroadcastBotOpts
welcomeGetOpts = do
  appDir <- getAppUserDataDirectory "popopx"
  opts@BroadcastBotOpts {coreOptions} <- getBroadcastBotOpts appDir "popopx_status_bot"
  putStrLn $ "POPOPX Chat Bot v" ++ versionNumber
  printDbOpts coreOptions
  pure opts

broadcastBot :: BroadcastBotOpts -> User -> ChatController -> IO ()
broadcastBot BroadcastBotOpts {publishers, welcomeMessage, prohibitedMessage} _user cc = do
  initializeBotAddress cc
  race_ (forever $ void getLine) . forever $ do
    (_, evt) <- atomically . readTBQueue $ outputQ cc
    case evt of
      Right (CEvtContactConnected _ ct _) -> do
        contactConnected ct
        sendMessage cc ct welcomeMessage
      Right CEvtNewChatItems {chatItems = (AChatItem _ SMDRcv (DirectChat ct) ci@ChatItem {content = CIRcvMsgContent mc}) : _}
        | sender `notElem` publishers -> do
            sendReply prohibitedMessage
            deleteMessage cc ct $ chatItemId' ci
        | allowContent mc ->
            void $ forkIO $
              sendChatCmd cc (SendMessageBroadcast mc) >>= \case
                Right CRBroadcastSent {successes, failures} ->
                  sendReply $ "Forwarded to " <> tshow successes <> " contact(s), " <> tshow failures <> " errors"
                r -> putStrLn $ "Error broadcasting message: " <> show r
        | otherwise ->
            sendReply "!1 Message is not supported!"
        where
          sendReply = sendComposedMessage cc ct (Just $ chatItemId' ci) . MCText
          sender = KnownContact {contactId = contactId' ct, localDisplayName = localDisplayName' ct}
          allowContent = \case
            MCText _ -> True
            MCLink {} -> True
            MCImage {} -> True
            _ -> False
      _ -> pure ()
  where
    contactConnected ct = putStrLn $ T.unpack (localDisplayName' ct) <> " connected"
