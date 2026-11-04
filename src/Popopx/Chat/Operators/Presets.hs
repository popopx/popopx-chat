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
import Popopx.Messaging.Agent.Env.SQLite (allRoles)
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
      serverDomains = ["popopxchat.com", "popopx.im"],
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
  [ "smp://HFjkcbBpzGMPaFE-26Nt7_C_DARppDPx_n8GU1FpnEk=@smp1.popopxchat.com,xbwfrzktm5y5rr7tbqffb6dlhmfwphvgxq3mje2i5hxudubbdmwe3mqd.onion",
    "smp://m9l1t8wzpWmS0EIsx8pwmE0eFZ7B_Ivbk6h8Y6ZgUis=@smp2.popopxchat.com,74mqm6si4tyszocoxd3pn2b3ua7kvi5couxbecnqpsyafvihafhqhrad.onion",
    "smp://p2HDkTFT-j5W7zcHVYOYv-yG9Tp0PHWbfbGsR3pa3fQ=@smp3.popopxchat.com,gui6ac3tdz2zhnhebhcs5gbazjvscn5ndrq6piho3zn4na7pep4jt2id.onion",
    "smp://WEJlXhDLGDoyGfI-qfSQeEwVEeNb213KZrvsOsZ4CP0=@smp4.popopxchat.com,3vc6he3qni4tgfc7zut4gusdkm7vxqy2bpo2u3p6cd6xo63cdis263yd.onion",
    "smp://ZaA0zXWiJSNnL8qzL_afRukN2nF0uW0aDGc50d-9NXo=@smp5.popopxchat.com,apluqrymydrfyyx4sruee36yyvz2c2bfjpgz2w3lznapeuy4ck7erqyd.onion",
    "smp://rZkzK2VanfssuY9eFI2nVY_l0JHFvGXzqnfbv5nttdc=@smp6.popopxchat.com,vaj56zfsxqbc5ycuufsiw6vmeaoq7hz24bfvxvvx6eib53ntzv4payyd.onion",
    "smp://cEmV5zcoayuU_Dzwv131WwWX7_KRvzrY0_4HgLePspQ=@smp7.popopxchat.com,jn7su2mipxprjcwvws6jmtfvfkhwaixq5f2ccb76cheeepepgki5wpad.onion",
    "smp://Yjlq51d6kTk61mbeCi_kT0U3SjaofPdD4Cy7hraCeZU=@smp8.popopxchat.com,5uibsj2lqpg744dzxbxsqnkwek4aogmjnokiaiorolkwxgghvgv54oyd.onion"
  ]

-- Please note: if any servers are removed from this list, they MUST be added to allPresetServers.
-- Otherwise previously created short links won't work.
--
-- !!! Also, if any servers need to be added, shortLinkPresetServers will need to be be split to two,
-- so that option used for restoring links is updated earlier, for backward/forward compatibility.
disabledPopopxChatSMPServers :: NonEmpty SMPServer
disabledPopopxChatSMPServers =
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
    "smp://N_McQS3F9TGoh4ER0QstUf55kGnNSd-wXfNPZ7HukcM=@smp19.popopx.im,i53bbtoqhlc365k6kxzwdp5w3cdt433s7bwh3y32rcbml2vztiyyz5id.onion",
    "smp://u2dS9sG8nMNURyZwqASV4yROM28Er0luVTx5X1CsMrU=@smp4.popopx.im,o5vmywmrnaxalvz6wi3zicyftgio6psuvyniis6gco6bp6ekl4cqj4id.onion",
    "smp://hpq7_4gGJiilmz5Rf-CswuU5kZGkm_zOIooSw6yALRg=@smp5.popopx.im,jjbyvoemxysm7qxap7m5d5m35jzv5qq6gnlv7s4rsn7tdwwmuqciwpid.onion",
    "smp://PQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo=@smp6.popopx.im,bylepyau3ty4czmn77q4fglvperknl4bi2eb2fdy2bh4jxtf32kf73yd.onion"
  ]

popopxChatRelays :: [NewUserChatRelay]
popopxChatRelays =
  [ presetChatRelay True (mkRelayProfile "PopopX Chat Relay 1" $ Just popopxChatImage) ["popopx.im"] (either error id $ strDecode "https://smp5.popopx.im/r#Fp5RWXkiRFg-hgcDwC2v-MWnPfvEf42RgCqREntW0mw"),
    presetChatRelay True (mkRelayProfile "PopopX Chat Relay 2" $ Just popopxChatImage) ["popopx.im"] (either error id $ strDecode "https://smp6.popopx.im/r#_qlQfogHGDJ8MAF2wKmkglRBM-xHR142gDJstKiGRQQ"),
    presetChatRelay True (mkRelayProfile "PopopX Chat Relay 3" $ Just popopxChatImage) ["popopx.im"] (either error id $ strDecode "https://smp4.popopx.im/r#yxNOMJcry5jMTRPEBVtGBATYaKeoRIsZRBPIDLx7x6M")
  ]

popopxXFTPServers :: [NewUserServer 'PXFTP]
popopxXFTPServers =
  [ newUserServer "xftp://YmYwI998zl-R1tK-7DFf_lrO0YTlCRJnagS1cie-Adc=@xftp1.popopxchat.com,j4ztwwbv6yzobdebh3mrzmjwcktv6bt4iwtc2gc7or5gxepkqsf4s6ad.onion",
    newUserServer "xftp://WTlITyAC1urEAEPzUwwR0BxYrLnS7vo5Dwi9aTVIVdA=@xftp6.popopxchat.com,pitpbrrovecq5vdix5ivrkszrkpevntvklxln6x4ux44zcukwwgggnqd.onion",
    newUserServer "xftp://t4D0UWJEElxdFmtAIJheq3c2qX-qOhohtaShi2SBwLw=@xftp8.popopxchat.com,erzzwgnoliml75nkgkucfbf575b6vg6fjixmkz636x7f3n4qpyut3lyd.onion"
  ]
