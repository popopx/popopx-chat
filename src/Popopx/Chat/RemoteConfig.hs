-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Chat.RemoteConfig
  ( RemoteServerConfig (..),
    RemoteOperatorConfig (..),
    RemoteChatRelayConfig (..),
    parseRemoteConfig,
    remoteConfigToServerCfgs,
  )
where

import Data.Aeson (FromJSON (..), eitherDecodeStrict', (.:?), (.:), (.!=), withObject)
import Data.ByteString (ByteString)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Popopx.Messaging.Agent.Env.SQLite (ServerCfg (..), allRoles)
import Popopx.Messaging.Encoding.String (StrEncoding (strDecode))
import Popopx.Messaging.Protocol (ProtoServerWithAuth, ProtocolType (PSMP, PXFTP))

data RemoteServerConfig = RemoteServerConfig
  { iceServers :: Maybe [Text],
    presetOperators :: Maybe [RemoteOperatorConfig],
    chatRelays :: Maybe [RemoteChatRelayConfig]
  }

instance FromJSON RemoteServerConfig where
  parseJSON = withObject "RemoteServerConfig" $ \o ->
    RemoteServerConfig
      <$> o .:? "ice_servers"
      <*> o .:? "preset_operators"
      <*> o .:? "chat_relays"

data RemoteOperatorConfig = RemoteOperatorConfig
  { rcOperatorTag :: Text,
    rcTradeName :: Maybe Text,
    rcSmpServers :: Maybe [Text],
    rcXftpServers :: Maybe [Text]
  }

instance FromJSON RemoteOperatorConfig where
  parseJSON = withObject "RemoteOperatorConfig" $ \o ->
    RemoteOperatorConfig
      <$> o .: "operator_tag"
      <*> o .:? "trade_name"
      <*> o .:? "smp_servers"
      <*> o .:? "xftp_servers"

data RemoteChatRelayConfig = RemoteChatRelayConfig
  { rcRelayName :: Text,
    rcRelayUrl :: Text,
    rcRelayDomains :: Maybe [Text],
    rcRelayEnabled :: Bool
  }

instance FromJSON RemoteChatRelayConfig where
  parseJSON = withObject "RemoteChatRelayConfig" $ \o ->
    RemoteChatRelayConfig
      <$> o .: "name"
      <*> o .: "url"
      <*> o .:? "domains"
      <*> o .:? "enabled" .!= True

parseRemoteConfig :: ByteString -> Either Text RemoteServerConfig
parseRemoteConfig = either (Left . T.pack) Right . eitherDecodeStrict'

remoteConfigToServerCfgs ::
  RemoteServerConfig ->
  Either Text ([ServerCfg 'PSMP], [ServerCfg 'PXFTP])
remoteConfigToServerCfgs RemoteServerConfig {presetOperators} =
  case presetOperators of
    Nothing -> Right ([], [])
    Just ops -> do
      smpCfgs <- concat <$> mapM parseSMPServers ops
      xftpCfgs <- concat <$> mapM parseXftpServers ops
      Right (smpCfgs, xftpCfgs)
  where
    parseSMPServers :: RemoteOperatorConfig -> Either Text [ServerCfg 'PSMP]
    parseSMPServers op = case rcSmpServers op of
      Nothing -> Right []
      Just uris -> mapM parseSMPServerCfg uris

    parseXftpServers :: RemoteOperatorConfig -> Either Text [ServerCfg 'PXFTP]
    parseXftpServers op = case rcXftpServers op of
      Nothing -> Right []
      Just uris -> mapM parseXFTPServerCfg uris

parseSMPServerCfg :: Text -> Either Text (ServerCfg 'PSMP)
parseSMPServerCfg uri =
  case strDecode (TE.encodeUtf8 uri) of
    Left e -> Left $ "failed to parse SMP server '" <> uri <> "': " <> T.pack e
    Right srv -> Right $ mkServerCfg (srv :: ProtoServerWithAuth 'PSMP)

parseXFTPServerCfg :: Text -> Either Text (ServerCfg 'PXFTP)
parseXFTPServerCfg uri =
  case strDecode (TE.encodeUtf8 uri) of
    Left e -> Left $ "failed to parse XFTP server '" <> uri <> "': " <> T.pack e
    Right srv -> Right $ mkServerCfg (srv :: ProtoServerWithAuth 'PXFTP)

mkServerCfg :: ProtoServerWithAuth p -> ServerCfg p
mkServerCfg srv =
  ServerCfg
    { server = srv,
      operator = Nothing,
      enabled = True,
      roles = allRoles
    }
