-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE CPP #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Chat.Terminal where

import Control.Monad
import qualified Data.List.NonEmpty as L
import Popopx.Chat (defaultChatConfig)
import Popopx.Chat.Controller
import Popopx.Chat.Core
import Popopx.Chat.Help (chatWelcome)
import Popopx.Chat.Library.Commands (_defaultNtfServers)
import Popopx.Chat.Operators
import Popopx.Chat.Operators.Presets (operatorPopopXChat, popopxChatRelays, popopxChatSMPServers, popopxXFTPServers)
import Popopx.Chat.Options
import Popopx.Chat.Terminal.Input
import Popopx.Chat.Terminal.Output
import Popopx.FileTransfer.Client.Presets (defaultXFTPServers)
import Popopx.Messaging.Client (NetworkConfig (..), SMPProxyFallback (..), SMPProxyMode (..), defaultNetworkConfig)
import Popopx.Messaging.Util (raceAny_)
#if !defined(dbPostgres)
import Control.Exception (handle, throwIO)
import qualified Data.ByteArray as BA
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Database.SQLite.Simple (SQLError (..))
import qualified Database.SQLite.Simple as DB
import Popopx.Chat.Options.DB
import System.IO (hFlush, hSetEcho, stdin, stdout)
#endif

terminalChatConfig :: ChatConfig
terminalChatConfig =
  defaultChatConfig
    { presetServers =
        PresetServers
          { operators =
              [ 
                -- PopopX Chat operator
                -- Relay configuration:
                --   - popopxChatRelays routes through smp1.popopxchat.com
                --   - Relay key must match the SMP server fingerprint (Kz9xR4vP2mN5qW7jL9hT3fY6cB0dA8gE1iO4kM7nPxQ=)
                --   - useChatRelays = 1 means 1 relay is used for message routing
                --   - All PopopX SMP/XFTP servers must be deployed before enabling in production
                --   - Domain: popopxchat.com (added to presetDomains in Chat.hs)
                PresetOperator
                  { operator = Just operatorPopopXChat,
                    smp = popopxChatSMPServers,
                    useSMP = 4,
                    xftp = popopxXFTPServers,
                    useXFTP = 3,
                    chatRelays = popopxChatRelays,
                    useChatRelays = 4
                  }
              ],
            ntf = _defaultNtfServers,
            netCfg =
              defaultNetworkConfig
                { smpProxyMode = SPMUnknown,
                  smpProxyFallback = SPFAllowProtected
                }
          },
      deviceNameForRemote = "POPOPX CLI"
    }

popopxChatTerminal :: WithTerminal t => ChatConfig -> ChatOpts -> t -> IO ()
popopxChatTerminal cfg options t = run options
  where
#if defined(dbPostgres)
    run opts =
      popopxChatCore cfg opts $ \u cc -> do
        ct <- newChatTerminal t opts
        when (firstTime cc) . printToTerminal ct $ chatWelcome u
        runChatTerminal ct cc opts
#else
    run opts@ChatOpts {coreOptions = coreOptions@CoreChatOpts {dbOptions}} =
      handle checkDBKeyError . popopxChatCore cfg opts $ \u cc -> do
        ct <- newChatTerminal t opts
        when (firstTime cc) . printToTerminal ct $ chatWelcome u
        runChatTerminal ct cc opts
      where
        checkDBKeyError :: SQLError -> IO ()
        checkDBKeyError e = case sqlError e of
          DB.ErrorNotADatabase -> do
            putStrLn $ "Database file is invalid or " <> if BA.null (dbKey dbOptions) then "encrypted." else "you passed an incorrect encryption key."
            run =<< getKeyOpts
          _ -> throwIO e
        getKeyOpts :: IO ChatOpts
        getKeyOpts = do
          putStr "Enter database encryption key (Ctrl-C to exit):"
          hFlush stdout
          hSetEcho stdin False
          key <- getLine
          hSetEcho stdin True
          putStrLn ""
          pure opts {coreOptions = coreOptions {dbOptions = dbOptions {dbKey = BA.convert $ encodeUtf8 $ T.pack key}}}
#endif

runChatTerminal :: ChatTerminal -> ChatController -> ChatOpts -> IO ()
runChatTerminal ct cc opts = raceAny_ [runTerminalInput ct cc, runTerminalOutput ct cc opts, runInputLoop ct cc]
