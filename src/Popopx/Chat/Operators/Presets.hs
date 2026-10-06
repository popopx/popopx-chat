-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Chat.Operators.Presets where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as L
import Data.Text (Text)
import Popopx.Chat.Library.Internal (popopxChatImage)
import Popopx.Chat.Operators
import Popopx.Chat.Protocol (mkRelayProfile)
import Popopx.Messaging.Agent.Env.SQLite (ServerRoles (..), allRoles)
import Popopx.Messaging.Agent.Store.Entity
import Popopx.Messaging.Encoding.String
import Popopx.Messaging.Protocol (ProtocolType (..), SMPServer)

operatorPopopXChat :: NewServerOperator
operatorPopopXChat =
  ServerOperator
    { operatorId = DBNewEntity,
      operatorTag = Just OTPopopx,
      tradeName = "PopopX Switch",
      legalName = Just "POPOPX Group",
      serverDomains = ["popopxchat.com", "popopchat.com", "popopxchat.xyz"],
      conditionsAcceptance = CARequired Nothing,
      enabled = True,
      smpRoles = allRoles,
      xftpRoles = allRoles
    }


-- Please note: if any servers are removed from the lists below, they MUST be added here.
-- Otherwise previously created short links won't work.
--
-- !!! Also, if any servers need to be added, shortLinkPresetServers will need to be be split to two,
-- so that option used for restoring links is updated earlier, for backward/forward compatibility.
allPresetServers :: NonEmpty SMPServer
allPresetServers = enabledPopopxChatSMPServers <> disabledPopopxChatSMPServers

popopxChatSMPServers :: [NewUserServer 'PSMP]
popopxChatSMPServers =
  map (presetServer' True) (L.toList enabledPopopxChatSMPServers)
    <> map (presetServer' False) (L.toList disabledPopopxChatSMPServers)

-- Please note: if any servers are removed from this list, they MUST be added to allPresetServers.
-- Otherwise previously created short links won't work.
--
-- !!! Also, if any servers need to be added, shortLinkPresetServers will need to be be split to two,
-- so that option used for restoring links is updated earlier, for backward/forward compatibility.
enabledPopopxChatSMPServers :: NonEmpty SMPServer
enabledPopopxChatSMPServers =
  [ "smp://q5TvFxQPkloaEGYhlLHejVWW7K31C57wq-YXjuwb258=@smp1.popopxchat.com,5eyw2zx2lykj6y6emgupunlldr7say3q5plkknvv6dddka5kcls63oqd.onion",
    "smp://h87w8XV_Q8bczkZvugDVB7RmqqpmBhIbgqYgXeZaQ4k=@ps1.popopxchat.xyz,2i2xq2epnpz43vuz7xzu74ewcfsmagbf4fytmcyayhuhhwc3thnq7fqd.onion",
    "smp://H7mJ2kP9xR4vT6wZ0cB3dA8fG1iO5qR9sV2wX7yZ4mN=@smp3.popopxchat.com,p5q8r1s4v7w0x3y6z9a2b5c8d1f4g7i0o3r6s9v2w5x.onion",
    "smp://Q5nL8jK2mP6xR9vT4wZ0cB3dA7fG1iO5qR9sV2wX8yZ=@smp4.popopxchat.com,q2r5s8v1w4x7y0z3a6b9c2d5f8g1i4o7r0s3v6w9x2y.onion"
  ]

-- Please note: if any servers are removed from this list, they MUST be added to allPresetServers.
-- Otherwise previously created short links won't work.
--
-- !!! Also, if any servers need to be added, shortLinkPresetServers will need to be be split to two,
-- so that option used for restoring links is updated earlier, for backward/forward compatibility.
disabledPopopxChatSMPServers :: NonEmpty SMPServer
disabledPopopxChatSMPServers =
  [ "smp://u2dS9sG8nMNURyZwqASV4yROM28Er0luVTx5X1CsMrU=@smp44.popopxchat.com,o5vmywmrnaxalvz6wi3zicyftgio6psuvyniis6gco6bp6ekl4cqj4id.onion",
    "smp://hpq7_4gGJiilmz5Rf-CswuU5kZGkm_zOIooSw6yALRg=@smp55.popopxchat.com,jjbyvoemxysm7qxap7m5d5m35jzv5qq6gnlv7s4rsn7tdwwmuqciwpid.onion",
    "smp://PQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo=@smp66.popopxchat.com,bylepyau3ty4czmn77q4fglvperknl4bi2eb2fdy2bh4jxtf32kf73yd.onion"
  ]

popopxChatRelays :: [NewUserChatRelay]
popopxChatRelays =
  [ presetChatRelay True (mkRelayProfile "PopopX Chat Relay 1" $ Just popopxChatImage) ["popopxchat.com"] (either error id $ strDecode "https://smp1.popopxchat.com/r#Kz9xR4vP2mN5qW7jL9hT3fY6cB0dA8gE1iO4kM7nPxQ="),
    presetChatRelay True (mkRelayProfile "POPOPX Chat Relay 2" $ Just popopxChatImage) ["popopxchat.com"] (either error id $ strDecode "https://smp55.popopxchat.com/r#Fp5RWXkiRFg-hgcDwC2v-MWnPfvEf42RgCqREntW0mw"),
    presetChatRelay True (mkRelayProfile "POPOPX Chat Relay 3" $ Just popopxChatImage) ["popopxchat.com"] (either error id $ strDecode "https://smp65.popopxchat.com/r#_qlQfogHGDJ8MAF2wKmkglRBM-xHR142gDJstKiGRQQ"),
    presetChatRelay True (mkRelayProfile "POPOPX Chat Relay 4" $ Just popopxChatImage) ["popopxchat.com"] (either error id $ strDecode "https://smp44.popopxchat.com/r#yxNOMJcry5jMTRPEBVtGBATYaKeoRIsZRBPIDLx7x6M")
  ]


popopxXFTPServers :: [NewUserServer 'PXFTP]
popopxXFTPServers =
  map
    (presetServer True)
    [ "xftp://R8vT2mN5qW7jL9hK3xP4fY6cB0dA1gE8iO4kM7nPxQz=@xftp1.popopxchat.com,r4s7v0w3x6y9z2a5b8c1d4f7g0i3o6r9s2v5w8x1y4z.onion",
      "xftp://J6kL2mP9xR4vT8wZ0cB3dA5fG7iO1qR5sV9wX2yZ6mN=@xftp2.popopxchat.com,t1u4x7y0z3a6b9c2d5f8g1i4o7r0s3v6w9x2y5z8a1b.onion",
      "xftp://M3nQ7rS2vW5xY8zA1bC4dF6gI0kO3pR6sV9wX2yZ5mN=@xftp3.popopxchat.com,u8a1b4c7d0f3g6i9o2p5r8s1v4w7x0y3z6a9b2c5d8f.onion"
    ]

-- | Default BinThere bot for burn-after-read messages
-- This is a placeholder - update with actual bot address after deployment
defaultBinThereBot :: (Text, Text)
defaultBinThereBot =
  ( "binthere",  -- bot_type
    ""           -- bot_address - to be configured after bot deployment
  )

-- | Default config bot for distributing server config and bot directory
-- This is a placeholder - update with actual bot address after deployment
defaultConfigBot :: (Text, Text)
defaultConfigBot =
  ( "config",    -- bot_type
    ""           -- bot_address - to be configured after bot deployment
  )
