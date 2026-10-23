{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}

module AgentTests.ServerChoice where

import AgentTests.FunctionalAPITests
import Control.Monad.IO.Class
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as M
import SMPAgentClient
import Popopx.Messaging.Agent (withAgentEnv)
import Popopx.Messaging.Agent.Client hiding (userServers)
import Popopx.Messaging.Agent.Env.SQLite
import Popopx.Messaging.Client (defaultNetworkConfig)
import Popopx.Messaging.Protocol
import Test.Hspec hiding (fit, it)
import Test.QuickCheck
import Util
import XFTPClient (testXFTPServer)

serverChoiceTests :: Spec
serverChoiceTests = do
  describe "Server operators" $ do
    it "should choose server of different operator" $ ioProperty $ testChooseDifferentOperator

operatorPopopxX :: Maybe OperatorId
operatorPopopxX = Just 1

operator2 :: Maybe OperatorId
operator2 = Just 2

testOp1Srv1 :: ProtoServerWithAuth 'PSMP
testOp1Srv1 = "smp://LcJU@test1.popopx.im"

testOp1Srv2 :: ProtoServerWithAuth 'PSMP
testOp1Srv2 = "smp://LcJU@test2.popopx.im"

testOp2Srv1 :: ProtoServerWithAuth 'PSMP
testOp2Srv1 = "smp://LcJU@srv1.example.com"

testOp2Srv2 :: ProtoServerWithAuth 'PSMP
testOp2Srv2 = "smp://LcJU@srv2.example.com"

testSMPServers :: NonEmpty (ServerCfg 'PSMP)
testSMPServers =
  [ presetServerCfg True allRoles operatorPopopxX testOp1Srv1,
    presetServerCfg True allRoles operatorPopopxX testOp1Srv2,
    presetServerCfg True proxyOnly operator2 testOp2Srv1,
    presetServerCfg True proxyOnly operator2 testOp2Srv2
  ]

storageOnly :: ServerRoles
storageOnly = ServerRoles {storage = True, proxy = False, names = False}

proxyOnly :: ServerRoles
proxyOnly = ServerRoles {storage = False, proxy = True, names = False}

initServers :: HasTestEnv => InitialAgentServers
initServers =
  InitialAgentServers
    { smp = M.fromList [(1, testSMPServers)],
      ntf = [testNtfServer],
      xftp = userServers [testXFTPServer],
      entitlements = M.empty,
      netCfg = defaultNetworkConfig,
      useServices = M.empty,
      presetDomains = [],
      presetServers = []
    }

testChooseDifferentOperator :: HasTestEnv => IO ()
testChooseDifferentOperator = withAgent 1 agentCfg initServers testDB $ \c -> runRight_ $ do
    -- chooses the only operator with storage role
    srv1 <- withAgentEnv c $ getNextServer c 1 storageSrvs []
    liftIO $ srv1 == testOp1Srv1 || srv1 == testOp1Srv2 `shouldBe` True
    -- chooses another server for storage
    srv2 <- withAgentEnv c $ getNextServer c 1 storageSrvs [protoServer testOp1Srv1]
    liftIO $ srv2 `shouldBe` testOp1Srv2
    -- chooses another operator for proxy
    srv3 <- withAgentEnv c $ getNextServer c 1 proxySrvs [protoServer srv1]
    liftIO $ srv3 == testOp2Srv1 || srv3 == testOp2Srv2 `shouldBe` True
    -- chooses another operator for proxy
    srv3' <- withAgentEnv c $ getNextServer c 1 proxySrvs [protoServer testOp1Srv1, protoServer testOp1Srv2]
    liftIO $ srv3' == testOp2Srv1 || srv3' == testOp2Srv2 `shouldBe` True
    -- chooses any other server
    srv4 <- withAgentEnv c $ getNextServer c 1 proxySrvs [protoServer testOp1Srv1, protoServer testOp2Srv1]
    liftIO $ srv4 == testOp1Srv2 || srv4 == testOp2Srv2 `shouldBe` True
