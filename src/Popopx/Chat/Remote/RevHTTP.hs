-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Chat.Remote.RevHTTP where

import Popopx.Messaging.Transport (TLS, TransportPeer (..))
import Popopx.Messaging.Transport.HTTP2 (defaultHTTP2BufferSize, getHTTP2Body)
import Popopx.Messaging.Transport.HTTP2.Client (HTTP2Client, HTTP2ClientError (..), attachHTTP2Client, bodyHeadSize, connTimeout, defaultHTTP2ClientConfig)
import Popopx.Messaging.Transport.HTTP2.Server (HTTP2Request (..), runHTTP2ServerWith)
import Popopx.RemoteControl.Discovery

attachRevHTTP2Client :: IO () -> TLS 'TServer -> IO (Either HTTP2ClientError HTTP2Client)
attachRevHTTP2Client disconnected = attachHTTP2Client config ANY_ADDR_V4 "0" disconnected defaultHTTP2BufferSize
  where
    config = defaultHTTP2ClientConfig {bodyHeadSize = doNotPrefetchHead, connTimeout = maxBound}

attachHTTP2Server :: TLS 'TClient -> (HTTP2Request -> IO ()) -> IO ()
attachHTTP2Server tls processRequest =
  runHTTP2ServerWith defaultHTTP2BufferSize ($ tls) $ \sessionId sessionALPN r sendResponse -> do
    reqBody <- getHTTP2Body r doNotPrefetchHead
    processRequest HTTP2Request {sessionId, sessionALPN, request = r, reqBody, sendResponse}

-- | Suppress storing initial chunk in bodyHead, forcing clients and servers to stream chunks
doNotPrefetchHead :: Int
doNotPrefetchHead = 0
