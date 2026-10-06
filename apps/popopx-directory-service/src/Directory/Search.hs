-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

module Directory.Search where

import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Popopx.Chat.Types

data SearchRequest = SearchRequest
  { searchType :: SearchType,
    searchTime :: UTCTime,
    lastGroup :: GroupId -- cursor for search
  }

data SearchType = STAll | STRecent | STSearch Text
