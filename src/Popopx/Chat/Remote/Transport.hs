-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Popopx.Chat.Remote.Transport where

import Control.Monad
import Control.Monad.Except
import Data.ByteString (ByteString)
import Data.ByteString.Builder (Builder, byteString)
import qualified Data.ByteString.Lazy as LB
import Data.Word (Word32)
import Popopx.Chat.Remote.Types
import Popopx.FileTransfer.Description (FileDigest (..))
import Popopx.FileTransfer.Transport (ReceiveFileError (..), receiveSbFile, sendEncFile)
import qualified Popopx.Messaging.Crypto as C
import qualified Popopx.Messaging.Crypto.Lazy as LC
import Popopx.Messaging.Encoding
import Popopx.Messaging.Util (liftError', liftEitherWith)
import Popopx.RemoteControl.Types (RCErrorType (..))
import UnliftIO
import UnliftIO.Directory (getFileSize)

type EncryptedFile = ((Handle, Word32), LC.SbState)

prepareEncryptedFile :: C.SbKeyNonce -> (Handle, Word32) -> ExceptT RemoteProtocolError IO EncryptedFile
prepareEncryptedFile (sk, nonce) f = do
  sbState <- liftEitherWith (const $ PRERemoteControl RCEEncrypt) $ LC.sbInit sk nonce
  pure (f, sbState)

sendEncryptedFile :: EncryptedFile -> (Builder -> IO ()) -> IO ()
sendEncryptedFile ((h, sz), sbState) send = do
  send $ byteString $ smpEncode ('\x01', sz + fromIntegral C.authTagSize)
  sendEncFile h send sbState sz

receiveEncryptedFile :: C.SbKeyNonce -> (Int -> IO ByteString) -> Word32 -> FileDigest -> FilePath -> ExceptT RemoteProtocolError IO ()
receiveEncryptedFile (sk, nonce) getChunk fileSize fileDigest toPath = do
  c <- liftIO $ getChunk 1
  unless (c == "\x01") $ throwError RPENoFile
  size <- liftError' RPEInvalidBody $ smpDecode <$> getChunk 4
  unless (size == fileSize + fromIntegral C.authTagSize) $ throwError RPEFileSize
  sbState <- liftEitherWith (const $ PRERemoteControl RCEDecrypt) $ LC.sbInit sk nonce
  liftError' fErr $ withFile toPath WriteMode $ \h -> receiveSbFile getChunk h sbState fileSize
  digest <- liftIO $ LC.sha512Hash <$> LB.readFile toPath
  unless (FileDigest digest == fileDigest) $ throwError RPEFileDigest
  where
    fErr RFESize = RPEFileSize
    fErr RFECrypto = PRERemoteControl RCEDecrypt

getFileInfo :: FilePath -> ExceptT RemoteProtocolError IO (Word32, FileDigest)
getFileInfo filePath = do
  fileDigest <- liftIO $ FileDigest . LC.sha512Hash <$> LB.readFile filePath
  fileSize' <- getFileSize filePath
  when (fileSize' > toInteger (maxBound :: Word32)) $ throwError RPEFileSize
  pure (fromInteger fileSize', fileDigest)
