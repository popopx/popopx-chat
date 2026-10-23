{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module SMPWeb
  ( smpGenerateSite,
    serverInformation,
  ) where

import Data.ByteString (ByteString)
import Data.String (fromString)
import Web.Embedded (embeddedContent)
import Popopx.Messaging.Encoding.String (strEncode)
import Popopx.Messaging.Server.Information
import Popopx.Messaging.Server.Main (popopxmqSource)
import qualified Popopx.Messaging.Server.Web as Web
import Popopx.Messaging.Server.Web (render, serverInfoSubsts, timedTTLText)
import Popopx.Messaging.Transport.Client (TransportHost (..))

smpGenerateSite :: ServerInformation -> Maybe TransportHost -> FilePath -> IO ()
smpGenerateSite si onionHost path =
  Web.generateSite embeddedContent (serverInformation si onionHost) smpLinkPages path

smpLinkPages :: [String]
smpLinkPages = ["contact", "invitation", "a", "c", "g", "r", "i"]

serverInformation :: ServerInformation -> Maybe TransportHost -> ByteString
serverInformation ServerInformation {config, information} onionHost = render (Web.indexHtml embeddedContent) substs
  where
    substs = [("smpConfig", Just "y"), ("xftpConfig", Nothing)] <> substConfig <> serverInfoSubsts popopxmqSource information <> [("onionHost", strEncode <$> onionHost), ("iniFileName", Just "smp-server.ini")]
    substConfig =
      [ ( "persistence",
          Just $ case persistence config of
            SPMMemoryOnly -> "In-memory only"
            SPMQueues -> "Queues"
            SPMMessages -> "Queues and messages"
        ),
        ("messageExpiration", Just $ maybe "Never" (fromString . timedTTLText) $ messageExpiration config),
        ("statsEnabled", Just . yesNo $ statsEnabled config),
        ("newQueuesAllowed", Just . yesNo $ newQueuesAllowed config),
        ("basicAuthEnabled", Just . yesNo $ basicAuthEnabled config)
      ]
    yesNo True = "Yes"
    yesNo False = "No"
