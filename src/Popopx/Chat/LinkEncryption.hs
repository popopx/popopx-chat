-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Popopx.Chat.LinkEncryption
  ( encryptConnFullLink,
    decryptConnLinkText,
    encryptedLinkPrefix,
    isEncryptedLink,
  )
where

import Control.Monad.Except
import qualified Crypto.Cipher.Types as AES
import qualified Data.ByteArray as BA
import qualified Data.ByteString as B
import qualified Data.ByteString.Base64.URL as B64U
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Crypto.Random (ChaChaDRG)
import Popopx.Messaging.Crypto (AuthTag (..), GCMIV (unGCMIV), Key (..), authTagSize, decryptAESNoPad, encryptAESNoPad, gcmIV, gcmIVSize, randomAesKey, randomGCMIV)
import UnliftIO (atomically)
import UnliftIO.STM (TVar)

aesKeySize :: Int
aesKeySize = 32

encryptedLinkPrefix :: Text
encryptedLinkPrefix = "popopx://enc#"

encryptedLinkPrefixLen :: Int
encryptedLinkPrefixLen = T.length encryptedLinkPrefix

isEncryptedLink :: Text -> Bool
isEncryptedLink t = T.isPrefixOf encryptedLinkPrefix t

encryptConnFullLink :: TVar ChaChaDRG -> Text -> IO Text
encryptConnFullLink rng plainText = do
  key <- atomically $ randomAesKey rng
  iv <- atomically $ randomGCMIV rng
  let plaintext = TE.encodeUtf8 plainText
  runExceptT (encryptAESNoPad key iv plaintext) >>= \case
    Left _ -> pure plainText
    Right (tag, ciphertext) -> do
      let payload = unKey key <> unGCMIV iv <> BA.convert (unAuthTag tag) <> ciphertext
          encoded = B64U.encode payload
      pure $ encryptedLinkPrefix <> TE.decodeUtf8 encoded

decryptConnLinkText :: Text -> IO (Either Text Text)
decryptConnLinkText t
  | not (isEncryptedLink t) = pure $ Left "not an encrypted link"
  | otherwise = do
      let encoded = TE.encodeUtf8 $ T.drop encryptedLinkPrefixLen t
      case B64U.decode encoded of
        Left e -> pure $ Left $ "base64 decode failed: " <> T.pack e
        Right payload -> do
          let minLen = aesKeySize + gcmIVSize + authTagSize
          if B.length payload < minLen
            then pure $ Left "payload too short"
            else do
              let (keyBytes, rest1) = B.splitAt aesKeySize payload
                  (ivBytes, rest2) = B.splitAt gcmIVSize rest1
                  (tagBytes, ciphertext) = B.splitAt authTagSize rest2
                  key = Key keyBytes
              case gcmIV ivBytes of
                Left _ -> pure $ Left "invalid IV"
                Right iv -> do
                  let tag = AuthTag $ AES.AuthTag $ BA.convert tagBytes
                  runExceptT (decryptAESNoPad key iv ciphertext tag) >>= \case
                    Left e -> pure $ Left $ "decryption failed: " <> T.pack (show e)
                    Right plaintext -> pure $ Right $ TE.decodeUtf8 plaintext
