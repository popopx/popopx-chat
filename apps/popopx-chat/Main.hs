-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

module Main where

import Server (popopxChatServer)
import Popopx.Chat.Badges.CLI (runBadgeCommand)
import Popopx.Chat.Terminal (terminalChatConfig)
import Popopx.Chat.Terminal.Main (popopxChatCLI)
import System.Environment (getArgs)

main :: IO ()
main = do
  args <- getArgs
  case args of
    ("badge" : _) -> runBadgeCommand args
    _ -> popopxChatCLI terminalChatConfig (Just popopxChatServer)
