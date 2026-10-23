module Main where

import Control.Logger.Simple
import Popopx.FileTransfer.Server.Main (xftpServerCLI_)
import Popopx.Messaging.Server.CLI (getEnvPath)
import Popopx.Messaging.Server.Web (serveStaticFiles)
import XFTPWeb (xftpGenerateSite)

defaultCfgPath :: FilePath
defaultCfgPath = "/etc/opt/popopx-xftp"

defaultLogPath :: FilePath
defaultLogPath = "/var/opt/popopx-xftp"

logCfg :: LogConfig
logCfg = LogConfig {lc_file = Nothing, lc_stderr = True}

main :: IO ()
main = do
  setLogLevel LogDebug -- change to LogError in production
  cfgPath <- getEnvPath "XFTP_SERVER_CFG_PATH" defaultCfgPath
  logPath <- getEnvPath "XFTP_SERVER_LOG_PATH" defaultLogPath
  withGlobalLogging logCfg $ xftpServerCLI_ xftpGenerateSite serveStaticFiles cfgPath logPath
