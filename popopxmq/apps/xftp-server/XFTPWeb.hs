{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module XFTPWeb
  ( xftpGenerateSite,
    xftpServerInformation,
  ) where

import Control.Monad (forM_)
import qualified Data.ByteString.Char8 as B
import Data.ByteString (ByteString)
import Data.FileEmbed (embedDir, embedFile)
import Data.Maybe (isJust)
import Data.String (fromString)
import Web.Embedded (embeddedContent)
import Popopx.FileTransfer.Server.Env (XFTPServerConfig (..))
import Popopx.Messaging.Encoding.String (strEncode)
import Popopx.Messaging.Server.Expiration (ExpirationConfig (..))
import Popopx.Messaging.Server.Information (ServerPublicInfo)
import Popopx.Messaging.Server.Main (popopxmqSource)
import qualified Popopx.Messaging.Server.Web as Web
import Popopx.Messaging.Server.Web (render, serverInfoSubsts, timedTTLText)
import Popopx.Messaging.Transport.Client (TransportHost (..))
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

xftpWebContent :: [(FilePath, ByteString)]
xftpWebContent = $(embedDir "apps/xftp-server/static/xftp-web-bundle/")

xftpMediaContent :: [(FilePath, ByteString)]
xftpMediaContent = $(embedDir "apps/xftp-server/static/media/")

xftpFilePageHtml :: ByteString
xftpFilePageHtml = $(embedFile "apps/xftp-server/static/file.html")

xftpGenerateSite :: XFTPServerConfig s -> Maybe ServerPublicInfo -> Maybe TransportHost -> FilePath -> IO ()
xftpGenerateSite cfg info onionHost path = do
  let substs = xftpSubsts cfg info onionHost
  Web.generateSite embeddedContent (render (Web.indexHtml embeddedContent) substs) [] path
  let xftpDir = path </> "xftp-web-bundle"
      mediaDir = path </> "media"
      fileDir = path </> "file"
  filePage xftpDir xftpWebContent
  filePage mediaDir xftpMediaContent
  createDirectoryIfMissing True fileDir
  B.writeFile (fileDir </> "index.html") $ render xftpFilePageHtml substs
  where
    filePage dir content_ = do
      createDirectoryIfMissing True dir
      forM_ content_ $ \(fp, content) -> B.writeFile (dir </> fp) content

xftpServerInformation :: XFTPServerConfig s -> Maybe ServerPublicInfo -> Maybe TransportHost -> ByteString
xftpServerInformation cfg info onionHost = render (Web.indexHtml embeddedContent) (xftpSubsts cfg info onionHost)

xftpSubsts :: XFTPServerConfig s -> Maybe ServerPublicInfo -> Maybe TransportHost -> [(ByteString, Maybe ByteString)]
xftpSubsts XFTPServerConfig {fileExpiration, logStatsInterval, allowNewFiles, newFileBasicAuth} information onionHost =
  [("smpConfig", Nothing), ("xftpConfig", Just "y")] <> substConfig <> serverInfoSubsts popopxmqSource information <> [("onionHost", strEncode <$> onionHost), ("iniFileName", Just "file-server.ini")]
  where
    substConfig =
      [ ("fileExpiration", Just . fromString . timedTTLText . ttl $ fileExpiration),
        ("statsEnabled", Just . yesNo $ isJust logStatsInterval),
        ("newUploadsAllowed", Just . yesNo $ allowNewFiles),
        ("basicAuthEnabled", Just . yesNo $ isJust newFileBasicAuth)
      ]
    yesNo True = "Yes"
    yesNo False = "No"
