module Main where

import Control.Logger.Simple
import Popopx.Messaging.Server.CLI (getEnvPath)
import Popopx.Messaging.Server.Main (smpServerCLI_)
import Popopx.Messaging.Server.Web (serveStaticFiles, attachStaticFiles)
import SMPWeb (smpGenerateSite)

defaultCfgPath :: FilePath
defaultCfgPath = "/etc/opt/popopx"

defaultLogPath :: FilePath
defaultLogPath = "/var/opt/popopx"

logCfg :: LogConfig
logCfg = LogConfig {lc_file = Nothing, lc_stderr = True}

main :: IO ()
main = do
  cfgPath <- getEnvPath "SMP_SERVER_CFG_PATH" defaultCfgPath
  logPath <- getEnvPath "SMP_SERVER_LOG_PATH" defaultLogPath
  withGlobalLogging logCfg $ smpServerCLI_ smpGenerateSite serveStaticFiles attachStaticFiles cfgPath logPath
