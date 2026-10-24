{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StrictData #-}
{-# LANGUAGE TupleSections #-}

module Popopx.Messaging.Agent.Store.SQLite.Migrations
  ( initialize,
    run,
    getCurrentMigrations,
  )
where

import Control.Monad (forM_, when)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe)
import Data.Text (Text, pack)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Data.Text.Encoding (decodeLatin1)
import Data.Time.Clock (getCurrentTime)
import Database.SQLite.Simple (Only (..), Query (..))
import qualified Database.SQLite.Simple as SQL
import qualified Database.SQLite3 as SQLite3
import Popopx.Messaging.Agent.Protocol (extraSMPServerHosts)
import qualified Popopx.Messaging.Agent.Store.DB as DB
import Popopx.Messaging.Agent.Store.SQLite.Common
import Popopx.Messaging.Agent.Store.SQLite.Migrations.M20230110_users
import Popopx.Messaging.Agent.Store.Shared
import Popopx.Messaging.Encoding.String
import Popopx.Messaging.Transport.Client (TransportHost)
import qualified System.IO as TIO
import Data.Text.Encoding (decodeUtf8)

getCurrentMigrations :: Maybe Query -> DB.Connection -> IO [Migration]
getCurrentMigrations migrationsTable DB.Connection {DB.conn} =
  map toMigration
    <$> SQL.query_ conn ("SELECT name, down FROM " <> table <> " ORDER BY name ASC;")
  where
    table = fromMaybe "migrations" migrationsTable
    toMigration (name, down) = Migration {name, up = "", down}

run :: DBStore -> Maybe Query -> Bool -> MigrationsToRun -> IO ()
run st migrationsTable vacuum = \case
  MTRUp [] -> pure ()
  MTRUp ms -> do
    mapM_ runUp ms
    when vacuum $ withConnection' st (`execSQL` "VACUUM;")
  MTRDown ms -> mapM_ runDown $ reverse ms
  MTRNone -> pure ()
  where
    table = fromMaybe "migrations" migrationsTable
    runUp Migration {name, up, down} = withTransaction' st $ \db -> do
      TIO.hPutStrLn TIO.stderr $ "[Migration] Running migration: " <> name
      when (name == "m20220811_onion_hosts") $ updateServers db
      insert db >> execSQL db up'
      TIO.hPutStrLn TIO.stderr $ "[Migration] Migration completed: " <> name
      where
        insert db = SQL.execute db ("INSERT INTO " <> table <> " (name, down, ts) VALUES (?,?,?)") . (name,down,) =<< getCurrentTime
        up'
          | dbNew st && name == "m20230110_users" = fromQuery new_m20230110_users
          | otherwise = up
        updateServers db = forM_ (M.assocs extraSMPServerHosts) $ \(h, h') ->
          let hs = decodeLatin1 . strEncode $ ([h, h'] :: NonEmpty TransportHost)
           in SQL.execute db "UPDATE servers SET host = ? WHERE host = ?" (hs, decodeLatin1 $ strEncode h)
    runDown DownMigration {downName, downQuery} = withTransaction' st $ \db -> do
      execSQL db downQuery
      SQL.execute db ("DELETE FROM " <> table <> " WHERE name = ?") (Only downName)
    execSQL db sql = do
      let statements = splitStatements sql
      T.putStrLn $ "[Migration-Debug] execSQL: split into " <> (pack (show $ length statements)) <> " statements"
      T.putStrLn "[Migration-Debug] execSQL: using SQL.execute_ (prepared statement API)"
      mapM_ (\stmt -> do
        let preview = T.take 80 stmt
        T.putStrLn $ "[Migration-Debug] execSQL: executing statement via SQL.execute_: " <> preview <> "..."
        SQL.execute_ db (Query stmt)
        T.putStrLn "[Migration-Debug] execSQL: statement completed successfully"
        ) statements
      T.putStrLn "[Migration-Debug] execSQL: all statements completed"

-- | Split multi-statement SQL into individual statements
-- Handles semicolons within strings and comments
splitStatements :: Text -> [Text]
splitStatements sql = filter (not . T.null) . map T.strip $ go sql False False "" []
  where
    go :: Text -> Bool -> Bool -> Text -> [Text] -> [Text]
    go remaining inString inComment currentStmt acc =
      case T.uncons remaining of
        Nothing -> 
          -- End of input, add final statement if non-empty
          if T.null currentStmt then reverse acc else reverse (currentStmt : acc)
        Just ('-', rest) | not inString && not inComment && T.isPrefixOf "-" rest ->
          -- Start of line comment - skip until newline
          let (_, afterNewline) = T.breakOn "\n" rest
          in go (T.drop 1 afterNewline) False False currentStmt acc
        Just ('/', rest) | not inString && not inComment && T.isPrefixOf "*" rest ->
          -- Start of block comment
          go (T.drop 1 rest) False True currentStmt acc
        Just ('*', rest) | not inString && inComment && T.isPrefixOf "/" rest ->
          -- End of block comment
          go (T.drop 1 rest) False False currentStmt acc
        Just ('\'', rest) | not inComment ->
          -- Toggle string state
          go rest (not inString) inComment (T.snoc currentStmt '\'') acc
        Just (';', rest) | not inString && not inComment ->
          -- Statement separator - add current statement to accumulator
          go rest inString inComment "" (currentStmt : acc)
        Just (c, rest) ->
          -- Regular character - add to current statement
          go rest inString inComment (T.snoc currentStmt c) acc

initialize :: DBStore -> Maybe Query -> IO ()
initialize st migrationsTable = withTransaction' st $ \db -> do
  cs :: [Text] <- map fromOnly <$> SQL.query_ db ("SELECT name FROM pragma_table_info('" <> table <> "')")
  case cs of
    [] -> createMigrations db
    _ -> when ("down" `notElem` cs) $ SQL.execute_ db $ "ALTER TABLE " <> table <> " ADD COLUMN down TEXT"
  where
    table = fromMaybe "migrations" migrationsTable
    createMigrations db =
      SQL.execute_ db $
        "CREATE TABLE IF NOT EXISTS "
          <> table
          <> " (name TEXT NOT NULL PRIMARY KEY, ts TEXT NOT NULL, down TEXT)"
-- Force rebuild
