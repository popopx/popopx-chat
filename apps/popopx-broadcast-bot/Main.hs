-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

module Main where

import Broadcast.Bot
import Broadcast.Options
import Popopx.Chat.Core
import Popopx.Chat.Terminal (terminalChatConfig)

main :: IO ()
main = do
  opts <- welcomeGetOpts
  popopxChatCore terminalChatConfig (mkChatOpts opts) $ broadcastBot opts
