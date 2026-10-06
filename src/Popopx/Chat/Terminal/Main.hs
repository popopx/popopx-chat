-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}

module Popopx.Chat.Terminal.Main where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM
import Control.Monad
import Data.Maybe (fromMaybe)
import Network.Socket
import Popopx.Chat.Controller (ChatConfig (..), ChatController (..), ChatError, ChatEvent (..), PresetServers (..), SimpleNetCfg (..), currentRemoteHost, versionNumber, versionString)
import Popopx.Chat.Core
import Popopx.Chat.Options
import Popopx.Chat.Options.DB
import Popopx.Chat.Terminal
import Popopx.Chat.View (ChatResponseEvent, smpProxyModeStr)
import Popopx.Messaging.Client (NetworkConfig (..), SocksMode (..))
import System.Directory (getAppUserDataDirectory)
import System.Exit (exitFailure)
import System.IO (BufferMode (..), hSetBuffering, stdout)
import System.Terminal (withTerminal)

popopxChatCLI :: ChatConfig -> Maybe (ServiceName -> ChatConfig -> ChatOpts -> IO ()) -> IO ()
popopxChatCLI cfg server_ = do
  appDir <- getAppUserDataDirectory "popopx"
  opts <- getChatOpts appDir "popopx_v1"
  popopxChatCLI' cfg opts server_

popopxChatCLI' :: ChatConfig -> ChatOpts -> Maybe (ServiceName -> ChatConfig -> ChatOpts -> IO ()) -> IO ()
popopxChatCLI' cfg opts@ChatOpts {chatCmd, chatCmdLog, chatCmdDelay, chatServerPort, coreOptions = CoreChatOpts {headless}} server_ = do
  if null chatCmd
    then case chatServerPort of
      Just chatPort -> case server_ of
        Just server -> server chatPort cfg opts
        Nothing -> putStrLn "Not allowed to run as a WebSockets server" >> exitFailure
      _
        | headless -> do
            hSetBuffering stdout LineBuffering
            welcome cfg opts
            popopxChatCore cfg opts runHeadless
        | otherwise -> runCLI
    else popopxChatCore cfg opts runCommand
  where
    runCLI = do
      welcome cfg opts
      t <- withTerminal pure
      popopxChatTerminal cfg opts t
    runHeadless user cc = forever $ do
      (rh, r) <- atomically $ readTBQueue $ outputQ cc
      case r of
        Left _ -> printResponseEvent (rh, Just user) cfg r
        Right _ -> pure ()
    runCommand user cc = do
      when (chatCmdLog /= CCLNone) . void . forkIO . forever $ do
        (_, r) <- atomically . readTBQueue $ outputQ cc
        case r of
          Right CEvtNewChatItems {} -> printResponse r
          _ -> when (chatCmdLog == CCLAll) $ printResponse r
      sendChatCmdStr cc chatCmd >>= printResponse
      threadDelay $ chatCmdDelay * 1000000
      where
        printResponse :: ChatResponseEvent r => Either ChatError r -> IO ()
        printResponse r = do
          rh <- readTVarIO $ currentRemoteHost cc
          printResponseEvent (rh, Just user) cfg r

welcome :: ChatConfig -> ChatOpts -> IO ()
welcome ChatConfig {presetServers = PresetServers {netCfg}} ChatOpts {coreOptions = CoreChatOpts {dbOptions, simpleNetCfg = SimpleNetCfg {socksProxy, socksMode, smpProxyMode_, smpProxyFallback_}}} =
  mapM_
    putStrLn
    [ versionString versionNumber,
      "db: " <> dbString dbOptions,
      maybe
        "direct network connection - use `/network` command or `-x` CLI option to connect via SOCKS5 at :9050"
        ((\sp -> "using SOCKS5 proxy " <> sp <> if socksMode == SMOnion then " for onion servers ONLY." else " for ALL servers.") . show)
        socksProxy,
      smpProxyModeStr
        (fromMaybe (smpProxyMode netCfg) smpProxyMode_)
        (fromMaybe (smpProxyFallback netCfg) smpProxyFallback_),
      "type \"/help\" or \"/h\" for usage info"
    ]
