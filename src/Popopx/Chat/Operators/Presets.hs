{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Chat.Operators.Presets where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as L
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
      tradeName = "PopopX Chat",
      legalName = Just "PopopX Chat Ltd",
      serverDomains = ["popopx.im"],
      conditionsAcceptance = CARequired Nothing,
      enabled = True,
      smpRoles = allRoles,
      xftpRoles = allRoles
    }

operatorFlux :: NewServerOperator
operatorFlux =
  ServerOperator
    { operatorId = DBNewEntity,
      operatorTag = Just OTFlux,
      tradeName = "Flux",
      legalName = Just "InFlux Technologies Limited",
      serverDomains = ["popopxonflux.com"],
      conditionsAcceptance = CARequired Nothing,
      enabled = True,
      smpRoles = ServerRoles {storage = False, proxy = True, names = True},
      xftpRoles = allRoles
    }

-- Please note: if any servers are removed from the lists below, they MUST be added here.
-- Otherwise previously created short links won't work.
--
-- !!! Also, if any servers need to be added, shortLinkPresetServers will need to be be split to two,
-- so that option used for restoring links is updated earlier, for backward/forward compatibility.
allPresetServers :: NonEmpty SMPServer
allPresetServers = enabledPopopxChatSMPServers <> disabledPopopxChatSMPServers <> fluxSMPServers_
  -- added for testing, not preset in the clients
  <> ["smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.popopx.im,dbxqutskmmbkbrs7ofi7pmopeyhgi5cxbjbh4ummgmep4r6bz4cbrcid.onion"]

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
  [ "smp://0YuTwO05YJWS8rkjn9eLJDjQhFKvIYd8d4xG8X1blIU=@smp8.popopx.im,beccx4yfxxbvyhqypaavemqurytl6hozr47wfc7uuecacjqdvwpw2xid.onion",
    "smp://SkIkI6EPd2D63F4xFKfHk7I1UGZVNn6k1QWZ5rcyr6w=@smp9.popopx.im,jssqzccmrcws6bhmn77vgmhfjmhwlyr3u7puw4erkyoosywgl67slqqd.onion",
    "smp://6iIcWT_dF2zN_w5xzZEY7HI2Prbh3ldP07YTyDexPjE=@smp10.popopx.im,rb2pbttocvnbrngnwziclp2f4ckjq65kebafws6g4hy22cdaiv5dwjqd.onion",
    "smp://1OwYGt-yqOfe2IyVHhxz3ohqo3aCCMjtB-8wn4X_aoY=@smp11.popopx.im,6ioorbm6i3yxmuoezrhjk6f6qgkc4syabh7m3so74xunb5nzr4pwgfqd.onion",
    "smp://UkMFNAXLXeAAe0beCa4w6X_zp18PwxSaSjY17BKUGXQ=@smp12.popopx.im,ie42b5weq7zdkghocs3mgxdjeuycheeqqmksntj57rmejagmg4eor5yd.onion",
    "smp://enEkec4hlR3UtKx2NMpOUK_K4ZuDxjWBO1d9Y4YXVaA=@smp14.popopx.im,aspkyu2sopsnizbyfabtsicikr2s4r3ti35jogbcekhm3fsoeyjvgrid.onion",
    "smp://h--vW7ZSkXPeOUpfxlFGgauQmXNFOzGoizak7Ult7cw=@smp15.popopx.im,oauu4bgijybyhczbnxtlggo6hiubahmeutaqineuyy23aojpih3dajad.onion",
    "smp://hejn2gVIqNU6xjtGM3OwQeuk8ZEbDXVJXAlnSBJBWUA=@smp16.popopx.im,p3ktngodzi6qrf7w64mmde3syuzrv57y55hxabqcq3l5p6oi7yzze6qd.onion",
    "smp://ZKe4uxF4Z_aLJJOEsC-Y6hSkXgQS5-oc442JQGkyP8M=@smp17.popopx.im,ogtwfxyi3h2h5weftjjpjmxclhb5ugufa5rcyrmg7j4xlch7qsr5nuqd.onion",
    "smp://PtsqghzQKU83kYTlQ1VKg996dW4Cw4x_bvpKmiv8uns=@smp18.popopx.im,lyqpnwbs2zqfr45jqkncwpywpbtq7jrhxnib5qddtr6npjyezuwd3nqd.onion",
    "smp://N_McQS3F9TGoh4ER0QstUf55kGnNSd-wXfNPZ7HukcM=@smp19.popopx.im,i53bbtoqhlc365k6kxzwdp5w3cdt433s7bwh3y32rcbml2vztiyyz5id.onion"
  ]

-- Please note: if any servers are removed from this list, they MUST be added to allPresetServers.
-- Otherwise previously created short links won't work.
--
-- !!! Also, if any servers need to be added, shortLinkPresetServers will need to be be split to two,
-- so that option used for restoring links is updated earlier, for backward/forward compatibility.
disabledPopopxChatSMPServers :: NonEmpty SMPServer
disabledPopopxChatSMPServers =
  [ "smp://u2dS9sG8nMNURyZwqASV4yROM28Er0luVTx5X1CsMrU=@smp4.popopx.im,o5vmywmrnaxalvz6wi3zicyftgio6psuvyniis6gco6bp6ekl4cqj4id.onion",
    "smp://hpq7_4gGJiilmz5Rf-CswuU5kZGkm_zOIooSw6yALRg=@smp5.popopx.im,jjbyvoemxysm7qxap7m5d5m35jzv5qq6gnlv7s4rsn7tdwwmuqciwpid.onion",
    "smp://PQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo=@smp6.popopx.im,bylepyau3ty4czmn77q4fglvperknl4bi2eb2fdy2bh4jxtf32kf73yd.onion"
  ]

popopxChatRelays :: [NewUserChatRelay]
popopxChatRelays =
  [ presetChatRelay True (mkRelayProfile "PopopX Chat Relay 1" $ Just popopxChatImage) ["popopx.im"] (either error id $ strDecode "https://smp5.popopx.im/r#Fp5RWXkiRFg-hgcDwC2v-MWnPfvEf42RgCqREntW0mw"),
    presetChatRelay True (mkRelayProfile "PopopX Chat Relay 2" $ Just popopxChatImage) ["popopx.im"] (either error id $ strDecode "https://smp6.popopx.im/r#_qlQfogHGDJ8MAF2wKmkglRBM-xHR142gDJstKiGRQQ"),
    presetChatRelay True (mkRelayProfile "PopopX Chat Relay 3" $ Just popopxChatImage) ["popopx.im"] (either error id $ strDecode "https://smp4.popopx.im/r#yxNOMJcry5jMTRPEBVtGBATYaKeoRIsZRBPIDLx7x6M")
  ]

fluxSMPServers :: [NewUserServer 'PSMP]
fluxSMPServers = map (presetServer' True) (L.toList fluxSMPServers_)

-- Please note: if any servers are removed from this list, they MUST be added to allPresetServers.
-- Otherwise previously created short links won't work.
--
-- !!! Also, if any servers need to be added, shortLinkPresetServers will need to be be split to two,
-- so that option used for restoring links is updated earlier, for backward/forward compatibility.
fluxSMPServers_ :: NonEmpty SMPServer
fluxSMPServers_ =
  [ "smp://xQW_ufMkGE20UrTlBl8QqceG1tbuylXhr9VOLPyRJmw=@smp1.popopxonflux.com,qb4yoanyl4p7o33yrknv4rs6qo7ugeb2tu2zo66sbebezs4cpyosarid.onion",
    "smp://LDnWZVlAUInmjmdpQQoIo6FUinRXGe0q3zi5okXDE4s=@smp2.popopxonflux.com,yiqtuh3q4x7hgovkomafsod52wvfjucdljqbbipg5sdssnklgongxbqd.onion",
    "smp://1jne379u7IDJSxAvXbWb_JgoE7iabcslX0LBF22Rej0=@smp3.popopxonflux.com,a5lm4k7ufei66cdck6fy63r4lmkqy3dekmmb7jkfdm5ivi6kfaojshad.onion",
    "smp://xmAmqj75I9mWrUihLUlI0ZuNLXlIwFIlHRq5Pb6cHAU=@smp4.popopxonflux.com,qpcz2axyy66u26hfdd2e23uohcf3y6c36mn7dcuilcgnwjasnrvnxjqd.onion",
    "smp://rWvBYyTamuRCBYb_KAn-nsejg879ndhiTg5Sq3k0xWA=@smp5.popopxonflux.com,4ao347qwiuluyd45xunmii4skjigzuuox53hpdsgbwxqafd4yrticead.onion",
    "smp://PN7-uqLBToqlf1NxHEaiL35lV2vBpXq8Nj8BW11bU48=@smp6.popopxonflux.com,hury6ot3ymebbr2535mlp7gcxzrjpc6oujhtfxcfh2m4fal4xw5fq6qd.onion"
  ]

fluxXFTPServers :: [NewUserServer 'PXFTP]
fluxXFTPServers =
  map
    (presetServer True)
    [ "xftp://92Sctlc09vHl_nAqF2min88zKyjdYJ9mgxRCJns5K2U=@xftp1.popopxonflux.com,apl3pumq3emwqtrztykyyoomdx4dg6ysql5zek2bi3rgznz7ai3odkid.onion",
      "xftp://YBXy4f5zU1CEhnbbCzVWTNVNsaETcAGmYqGNxHntiE8=@xftp2.popopxonflux.com,c5jjecisncnngysah3cz2mppediutfelco4asx65mi75d44njvua3xid.onion",
      "xftp://ARQO74ZSvv2OrulRF3CdgwPz_AMy27r0phtLSq5b664=@xftp3.popopxonflux.com,dc4mohiubvbnsdfqqn7xhlhpqs5u4tjzp7xpz6v6corwvzvqjtaqqiqd.onion",
      "xftp://ub2jmAa9U0uQCy90O-fSUNaYCj6sdhl49Jh3VpNXP58=@xftp4.popopxonflux.com,4qq5pzier3i4yhpuhcrhfbl6j25udc4czoyascrj4yswhodhfwev3nyd.onion",
      "xftp://Rh19D5e4Eez37DEE9hAlXDB3gZa1BdFYJTPgJWPO9OI=@xftp5.popopxonflux.com,q7itltdn32hjmgcqwhow4tay5ijetng3ur32bolssw32fvc5jrwvozad.onion",
      "xftp://0AznwoyfX8Od9T_acp1QeeKtxUi676IBIiQjXVwbdyU=@xftp6.popopxonflux.com,upvzf23ou6nrmaf3qgnhd6cn3d74tvivlmz3p7wdfwq6fhthjrjiiqid.onion"
    ]
