-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE OverloadedStrings #-}

module Popopx.Chat.Operators.Conditions where

import Data.Char (isSpace)
import Data.Text (Text)
import qualified Data.Text as T

stripFrontMatter :: Text -> Text
stripFrontMatter =
  T.unlines
    -- . dropWhile ("# " `T.isPrefixOf`) -- strip title
    . dropWhile (T.all isSpace)
    . dropWhile fm
    . (\ls -> let ls' = dropWhile (not . fm) ls in if null ls' then ls else ls')
    . dropWhile fm
    . T.lines
  where
    fm = ("---" `T.isPrefixOf`)
