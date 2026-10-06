-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -fno-warn-ambiguous-fields #-}

module Popopx.Chat.Library.Internal where

import qualified Codec.Compression.Zstd as Z1
import Control.Applicative ((<|>))
import Control.Concurrent.STM (retry)
import Control.Logger.Simple
import Control.Monad
import Control.Monad.Except
import Control.Monad.IO.Unlift
import Control.Monad.Reader
import Crypto.Random (ChaChaDRG)
import qualified Data.Aeson as J
import Data.Bifunctor (first)
import Data.ByteString.Char8 (ByteString)
import qualified Data.ByteString.Char8 as B
import qualified Data.ByteString.Lazy.Char8 as LB
import Data.Char (isDigit)
import Data.Containers.ListUtils (nubOrd)
import Data.Either (partitionEithers, rights)
import Data.Fixed (div')
import Data.Foldable (foldr')
import Data.Functor (($>))
import Data.Functor.Identity
import Data.Int (Int64)
import Data.List (find, foldl', mapAccumL, partition)
import Data.List.NonEmpty (NonEmpty (..), (<|))
import qualified Data.List.NonEmpty as L
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe (catMaybes, fromMaybe, isJust, isNothing, mapMaybe)
import qualified Data.Set as S
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Data.Time (addUTCTime)
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), diffUTCTime, getCurrentTime, nominalDiffTimeToSeconds, secondsToDiffTime)
import Popopx.Chat.Badges (BadgeCredential (..), ProofPresHeader (..), BadgeProof (..), BadgeStatus (..), LocalBadge (..), badgeProof, mkBadgeStatus, verifyBadge)
import Popopx.Chat.Names (PopopxDomainClaim (..), claimDomain)
import Popopx.Chat.Call
import Popopx.Chat.Controller
import Popopx.Chat.Files
import Popopx.Chat.Markdown
import Popopx.Chat.Messages
import Popopx.Chat.Messages.Batch (BatchMode (..), MsgBatch (..), batchElements, batchMessages, encodeBatchElement, encodeBinaryBatch, encodeFwdElement)
import Popopx.Chat.Messages.CIContent
import Popopx.Chat.Messages.CIContent.Events
import Popopx.Chat.Operators
import Popopx.Chat.ProfileGenerator (generateRandomProfile)
import Popopx.Chat.Protocol
import Popopx.Chat.Store
import Popopx.Chat.Store.ContactRequest
import Popopx.Chat.Store.Direct
import Popopx.Chat.Store.Files
import Popopx.Chat.Store.Groups
import Popopx.Chat.Store.Messages
import Popopx.Chat.Store.Profiles
import Popopx.Chat.Store.Shared
import Popopx.Chat.Types
import Popopx.Chat.Types.MemberRelations
import Popopx.Chat.Types.Preferences
import Popopx.Chat.Types.Shared
import Popopx.Chat.Util (encryptFile, shuffle)
import Popopx.FileTransfer.Description (FileDescriptionURI (..), ValidFileDescription)
import qualified Popopx.FileTransfer.Description as FD
import qualified Popopx.Messaging.Crypto.Lazy as LC
import Popopx.FileTransfer.Protocol (FileParty (..), FilePartyI)
import Popopx.FileTransfer.Types (RcvFileId, SndFileId)
import Popopx.Messaging.Agent
import Popopx.Messaging.Agent.Client (getFastNetworkConfig, ipAddressProtected, withLockMap)
import Popopx.Messaging.Agent.Env.SQLite (AgentConfig (..), ServerCfg (..))
import Popopx.Messaging.Agent.Lock (withLock)
import Popopx.Messaging.Agent.Protocol
import qualified Popopx.Messaging.Agent.Protocol as AP (AgentErrorType (..))
import qualified Popopx.Messaging.Agent.Store.DB as DB
import Popopx.Messaging.Client (NetworkConfig (..), NetworkRequestMode (..))
import Popopx.Messaging.Compression (compressionLevel, limitDecompress')
import qualified Popopx.Messaging.Crypto as C
import Popopx.Messaging.Crypto.File (CryptoFile (..), CryptoFileArgs (..))
import qualified Popopx.Messaging.Crypto.File as CF
import Popopx.Messaging.Crypto.Ratchet (PQEncryption (..), PQSupport (..), pattern IKPQOff, pattern PQEncOff, pattern PQEncOn, pattern PQSupportOff, pattern PQSupportOn)
import qualified Popopx.Messaging.Crypto.Ratchet as CR
import Popopx.Messaging.Encoding (smpEncode)
import Popopx.Messaging.Encoding.String
import Popopx.Messaging.Protocol (MsgBody, MsgFlags (..), ProtoServerWithAuth (..), ProtocolServer, ProtocolTypeI (..), SProtocolType (..), SubscriptionMode (..), UserProtocol, XFTPServer)
import qualified Popopx.Messaging.Protocol as SMP
import qualified Popopx.Messaging.TMap as TM
import Popopx.Messaging.Util
import Popopx.Messaging.Version
import System.FilePath (takeFileName, (</>))
import System.IO (Handle, IOMode (..), hFlush)
import UnliftIO.Concurrent (forkFinally, mkWeakThreadId)
import UnliftIO.Directory
import UnliftIO.IO (hClose, openFile)
import UnliftIO.STM

maxMsgReactions :: Int
maxMsgReactions = 3

maxRcvMentions :: Int
maxRcvMentions = 5

maxSndMentions :: Int
maxSndMentions = 3

withChatLock :: Text -> CM a -> CM a
withChatLock name action = asks chatLock >>= \l -> withLock l name action

withEntityLock :: Text -> ChatLockEntity -> CM a -> CM a
withEntityLock name entity action = do
  chatLock <- asks chatLock
  ls <- asks entityLocks
  atomically $ unlessM (isEmptyTMVar chatLock) retry
  withLockMap ls entity name action

withInvitationLock :: Text -> ByteString -> CM a -> CM a
withInvitationLock name = withEntityLock name . CLInvitation
{-# INLINE withInvitationLock #-}

withConnectionLock :: Text -> Int64 -> CM a -> CM a
withConnectionLock name = withEntityLock name . CLConnection
{-# INLINE withConnectionLock #-}

withContactLock :: Text -> ContactId -> CM a -> CM a
withContactLock name = withEntityLock name . CLContact
{-# INLINE withContactLock #-}

withGroupLock :: Text -> GroupId -> CM a -> CM a
withGroupLock name = withEntityLock name . CLGroup
{-# INLINE withGroupLock #-}

withUserContactLock :: Text -> Int64 -> CM a -> CM a
withUserContactLock name = withEntityLock name . CLUserContact
{-# INLINE withUserContactLock #-}

withContactRequestLock :: Text -> Int64 -> CM a -> CM a
withContactRequestLock name = withEntityLock name . CLContactRequest
{-# INLINE withContactRequestLock #-}

withFileLock :: Text -> Int64 -> CM a -> CM a
withFileLock name = withEntityLock name . CLFile
{-# INLINE withFileLock #-}

useServerCfgs :: forall p. UserProtocol p => SProtocolType p -> RandomAgentServers -> [(Text, ServerOperator)] -> [UserServer p] -> NonEmpty (ServerCfg p)
useServerCfgs p RandomAgentServers {smpServers, xftpServers} opDomains =
  fromMaybe (rndAgentServers p) . L.nonEmpty . agentServerCfgs p opDomains
  where
    rndAgentServers :: SProtocolType p -> NonEmpty (ServerCfg p)
    rndAgentServers = \case
      SPSMP -> smpServers
      SPXFTP -> xftpServers

contactCITimed :: Contact -> CM (Maybe CITimed)
contactCITimed ct = sndContactCITimed False ct Nothing

sndContactCITimed :: Bool -> Contact -> Maybe Int -> CM (Maybe CITimed)
sndContactCITimed live = sndCITimed_ live . contactTimedTTL

sndGroupCITimed :: Bool -> GroupInfo -> Maybe Int -> CM (Maybe CITimed)
sndGroupCITimed live = sndCITimed_ live . groupTimedTTL

sndCITimed_ :: Bool -> Maybe (Maybe Int) -> Maybe Int -> CM (Maybe CITimed)
sndCITimed_ live chatTTL itemTTL =
  forM (chatTTL >>= (itemTTL <|>)) $ \ttl ->
    CITimed ttl
      <$> if live
        then pure Nothing
        else Just . addUTCTime (realToFrac ttl) <$> liftIO getCurrentTime

callTimed :: Contact -> ACIContent -> CM (Maybe CITimed)
callTimed ct aciContent =
  case aciContentCallStatus aciContent of
    Just callStatus
      | callComplete callStatus -> do
          contactCITimed ct
    _ -> pure Nothing
  where
    aciContentCallStatus :: ACIContent -> Maybe CICallStatus
    aciContentCallStatus (ACIContent _ (CISndCall st _)) = Just st
    aciContentCallStatus (ACIContent _ (CIRcvCall st _)) = Just st
    aciContentCallStatus _ = Nothing

toggleNtf :: GroupMember -> Bool -> CM ()
toggleNtf m ntfOn =
  when (memberActive m) $
    forM_ (memberConnId m) $ \connId ->
      withAgent (\a -> toggleConnectionNtfs a connId ntfOn) `catchAllErrors` eToView

prepareGroupMsg :: DB.Connection -> User -> GroupInfo -> Maybe MsgScope -> ShowGroupAsSender -> MsgContent -> Map MemberName MsgMention -> Maybe ChatItemId -> Maybe CIForwardedFrom -> Maybe FileInvitation -> Maybe CITimed -> Bool -> ExceptT StoreError IO (ChatMsgEvent 'Json, Maybe (CIQuote 'CTGroup))
prepareGroupMsg db user g@GroupInfo {membership} msgScope showGroupAsSender mc mentions quotedItemId_ itemForwarded fInv_ timed_ live = do
  (mc', quotedItem_) <- case (quotedItemId_, itemForwarded) of
    (Nothing, Nothing) -> pure (mcSimple mc, Nothing)
    (Nothing, Just _) -> pure (mcForward mc, Nothing)
    (Just quotedItemId, Nothing) -> do
      CChatItem _ qci@ChatItem {meta = CIMeta {itemTs, itemSharedMsgId}, formattedText, mentions = quoteMentions, file} <-
        getGroupCIWithReactions db user g quotedItemId
      (origQmc, qd, sent, member_) <- quoteData qci membership
      let msgRef = MsgRef {msgId = itemSharedMsgId, sentAt = itemTs, sent, memberId = memberId' <$> member_}
          qmc = quoteContent mc origQmc file
          (qmc', ft', _) = updatedMentionNames qmc formattedText quoteMentions
          quotedItem = CIQuote {chatDir = qd, itemId = Just quotedItemId, sharedMsgId = itemSharedMsgId, sentAt = itemTs, content = qmc', formattedText = ft'}
      pure (mcQuote QuotedMsg {msgRef, content = qmc'} mc, Just quotedItem)
    (Just _, Just _) -> throwError SEInvalidQuote
  let mc'' = mc' {mentions = MsgMentions mentions, file = fInv_, ttl = ttl' <$> timed_, live = justTrue live, scope = msgScope, asGroup = justTrue showGroupAsSender}
  pure (XMsgNew mc'', quotedItem_)
  where
    quoteData :: ChatItem c d -> GroupMember -> ExceptT StoreError IO (MsgContent, CIQDirection 'CTGroup, Bool, Maybe GroupMember)
    quoteData ChatItem {meta = CIMeta {itemDeleted = Just _}} _ = throwError SEInvalidQuote
    quoteData ChatItem {chatDir = CIGroupSnd, content = CISndMsgContent qmc, meta = CIMeta {showGroupAsSender = sentAsGroup}} membership'
      | sentAsGroup = pure (qmc, CIQGroupSnd, True, Nothing)
      | otherwise = pure (qmc, CIQGroupSnd, True, Just membership')
    quoteData ChatItem {chatDir = CIGroupRcv m, content = CIRcvMsgContent qmc} _ = pure (qmc, CIQGroupRcv $ Just m, False, Just m)
    quoteData ChatItem {chatDir = CIChannelRcv, content = CIRcvMsgContent qmc} _ = pure (qmc, CIQGroupRcv Nothing, False, Nothing)
    quoteData _ _ = throwError SEInvalidQuote

updatedMentionNames :: MsgContent -> Maybe MarkdownList -> Map MemberName CIMention -> (MsgContent, Maybe MarkdownList, Map MemberName CIMention)
updatedMentionNames mc ft_ mentions = case ft_ of
  Just ft
    | not (null ft) && not (null mentions) && not (all sameName $ M.assocs mentions) ->
        let (mentions', ft') = mapAccumL update M.empty ft
            text = T.concat $ map markdownText ft'
         in (mc {text} :: MsgContent, Just ft', mentions')
  _ -> (mc, ft_, mentions)
  where
    sameName (name, CIMention {memberRef}) = case memberRef of
      Just CIMentionMember {displayName} -> case T.stripPrefix displayName name of
        Just rest
          | T.null rest -> True
          | otherwise -> case T.uncons rest of
              Just ('_', suffix) -> T.all isDigit suffix
              _ -> False
        Nothing -> False
      Nothing -> True
    update mentions' ft@(FormattedText f _) = case f of
      Just (Mention name) -> case M.lookup name mentions of
        Just mm@CIMention {memberRef} ->
          let name' = uniqueMentionName 0 $ case memberRef of
                Just CIMentionMember {displayName} -> displayName
                Nothing -> name
           in (M.insert name' mm mentions', FormattedText (Just $ Mention name') ('@' `T.cons` viewName name'))
        Nothing -> (mentions', ft)
      _ -> (mentions', ft)
      where
        uniqueMentionName :: Int -> Text -> Text
        uniqueMentionName pfx name =
          let prefixed = if pfx == 0 then name else (name `T.snoc` '_') <> tshow pfx
           in if prefixed `M.member` mentions' then uniqueMentionName (pfx + 1) name else prefixed

getCIMentions :: DB.Connection -> User -> GroupInfo -> Maybe MarkdownList -> Map MemberName GroupMemberId -> ExceptT StoreError IO (Map MemberName CIMention)
getCIMentions db user GroupInfo {groupId} ft_ mentions = case ft_ of
  Just ft | not (null ft) && not (null mentions) -> do
    let msgMentions = S.fromList $ mentionedNames ft
        n = M.size mentions
    -- prevent "invisible" and repeated-with-different-name mentions (when the same member is mentioned via another name)
    unless (n <= maxSndMentions && all (`S.member` msgMentions) (M.keys mentions) && S.size (S.fromList $ M.elems mentions) == n) $
      throwError SEInvalidMention
    mapM (getMentionedGroupMember db user groupId) mentions
  _ -> pure M.empty

getRcvCIMentions :: DB.Connection -> User -> GroupInfo -> Maybe MarkdownList -> Map MemberName MsgMention -> IO (Map MemberName CIMention)
getRcvCIMentions db user GroupInfo {groupId} ft_ mentions = case ft_ of
  Just ft
    | not (null ft) && not (null mentions) ->
        let mentions' = uniqueMsgMentions maxRcvMentions mentions $ mentionedNames ft
         in mapM (getMentionedMemberByMemberId db user groupId) mentions'
  _ -> pure M.empty

-- prevent "invisible" and repeated-with-different-name mentions
uniqueMsgMentions :: Int -> Map MemberName MsgMention -> [ContactName] -> Map MemberName MsgMention
uniqueMsgMentions maxMentions mentions = go M.empty S.empty 0
  where
    go acc _ _ [] = acc
    go acc seen n (name : rest)
      | n >= maxMentions = acc
      | otherwise = case M.lookup name mentions of
          Just mm@MsgMention {memberId}
            | S.notMember memberId seen ->
                go (M.insert name mm acc) (S.insert memberId seen) (n + 1) rest
          _ -> go acc seen n rest

getMessageMentions :: DB.Connection -> User -> GroupId -> Text -> IO (Map MemberName GroupMemberId)
getMessageMentions db user gId msg = case parseMaybeMarkdownList msg of
  Just ft | not (null ft) -> M.fromList . catMaybes <$> mapM get (nubOrd $ mentionedNames ft)
  _ -> pure M.empty
  where
    get name =
      fmap (name,) . eitherToMaybe
        <$> runExceptT (getGroupMemberIdByName db user gId name)

msgContentTexts :: MsgContent -> (Text, Maybe MarkdownList)
msgContentTexts mc = let t = msgContentText mc in (t, parseMaybeMarkdownList t)

ciContentTexts :: CIContent d -> (Text, Maybe MarkdownList)
ciContentTexts content = let t = ciContentToText content in (t, parseMaybeMarkdownList t)

quoteContent :: forall d. MsgContent -> MsgContent -> Maybe (CIFile d) -> MsgContent
quoteContent mc qmc ciFile_
  | replaceContent = MCText qTextOrFile
  | otherwise = case qmc of
      MCImage _ image -> MCImage qTextOrFile image
      MCFile _ -> MCFile qTextOrFile
      -- consider same for voice messages
      -- MCVoice _ voice -> MCVoice qTextOrFile voice
      _ -> qmc
  where
    -- if the message we're quoting with is one of the "large" MsgContents
    -- we replace the quote's content with MCText
    replaceContent = case mc of
      MCText _ -> False
      MCFile _ -> False
      MCLink {} -> True
      MCImage {} -> True
      MCVideo {} -> True
      MCVoice {} -> False
      MCReport {} -> False
      MCChat {} -> True
      MCUnknown {} -> True
    qText = msgContentText qmc
    getFileName :: CIFile d -> String
    getFileName CIFile {fileName} = fileName
    qFileName = maybe qText (T.pack . getFileName) ciFile_
    qTextOrFile = if T.null qText then qFileName else qText

prohibitedGroupContent :: GroupInfo -> GroupMember -> Maybe GroupChatScopeInfo -> MsgContent -> Maybe MarkdownList -> Maybe f -> Bool -> Maybe GroupFeature
prohibitedGroupContent gInfo@GroupInfo {membership = mem@GroupMember {memberRole = userRole}} m scopeInfo mc ft file_ sent
  | not supportAllowed = Just GFSupport
  | isVoice mc && not (groupFeatureMemberAllowed SGFVoice m gInfo) && not hostApprovalVoice = Just GFVoice
  | isNothing scopeInfo && not (isVoice mc) && (isJust file_ || isMedia mc) && not (groupFeatureMemberAllowed SGFFiles m gInfo) = Just GFFiles
  | isNothing scopeInfo && isReport mc && (badReportUser || not (groupFeatureAllowed SGFReports gInfo)) = Just GFReports
  | isNothing scopeInfo && prohibitedPopopxLinks gInfo m mc ft = Just GFPopopxLinks
  | otherwise = Nothing
  where
    supportAllowed = case scopeInfo of
      Just (GCSIMemberSupport scopeMem_) ->
        groupFeatureAllowed SGFSupport gInfo || isJust (supportChat $ fromMaybe mem scopeMem_)
      Nothing -> True
    hostApprovalVoice
      | sent = userRole >= GRAdmin && sendApprovalPhase
      | otherwise = memberCategory m == GCHostMember && hostApprovalPhase
    hostApprovalPhase = case scopeInfo of
      Just (GCSIMemberSupport Nothing) -> memberStatus mem == GSMemPendingApproval
      _ -> False
    sendApprovalPhase = case scopeInfo of
      Just (GCSIMemberSupport (Just scopeMem)) -> memberStatus scopeMem == GSMemPendingApproval
      _ -> False
    -- admins cannot send reports, non-admins cannot receive reports
    badReportUser
      | sent = userRole >= GRModerator
      | otherwise = userRole < GRModerator

prohibitedPopopxLinks :: GroupInfo -> GroupMember -> MsgContent -> Maybe MarkdownList -> Bool
prohibitedPopopxLinks gInfo m mc ft =
  not (groupFeatureMemberAllowed SGFPopopxLinks m gInfo)
    && (isChatLink mc || maybe False (any ftIsPopopxLink) ft || hasObfuscatedPopopxLink (msgContentText mc))
  where
    isChatLink = \case
      MCChat {} -> True
      _ -> False

ftIsPopopxLink :: FormattedText -> Bool
ftIsPopopxLink FormattedText {format} = maybe False isPopopxLink format

roundedFDCount :: Int -> Int
roundedFDCount n
  | n <= 0 = 4
  | otherwise = max 4 $ fromIntegral $ (2 :: Integer) ^ (ceiling (logBase 2 (fromIntegral n) :: Double) :: Integer)

xftpSndFileTransfer_ :: User -> CryptoFile -> Integer -> Int -> Maybe ContactOrGroup -> CM (FileInvitation, CIFile 'MDSnd, FileTransferMeta)
xftpSndFileTransfer_ user file@(CryptoFile filePath cfArgs) fileSize n contactOrGroup_ = do
  let fileName = takeFileName filePath
      fInv = xftpFileInvitation fileName fileSize dummyFileDescr
  fsFilePath <- lift $ toFSFilePath filePath
  let srcFile = CryptoFile fsFilePath cfArgs
  aFileId <- withAgent $ \a -> xftpSendFile a (aUserId user) srcFile (roundedFDCount n)
  -- TODO CRSndFileStart event for XFTP
  chSize <- asks $ fileChunkSize . config
  ft@FileTransferMeta {fileId} <- withStore' $ \db -> createSndFileTransferXFTP db user contactOrGroup_ file fInv (AgentSndFileId aFileId) Nothing chSize
  let fileSource = Just $ CryptoFile filePath cfArgs
      ciFile = CIFile {fileId, fileName, fileSize, fileSource, fileStatus = CIFSSndStored, fileProtocol = FPXFTP}
  pure (fInv, ciFile, ft)

cryptoFileDigest :: CryptoFile -> CM FD.FileDigest
cryptoFileDigest (CryptoFile filePath cfArgs) = do
  fsPath <- lift $ toFSFilePath filePath
  r <- liftIO $ runExceptT $ CF.readFile (CryptoFile fsPath cfArgs)
  either (throwChatError . CEInternalError . show) (pure . FD.FileDigest . LC.sha512Hash) r

xftpSndFileRedirect :: User -> FileTransferId -> ValidFileDescription 'FRecipient -> CM FileTransferMeta
xftpSndFileRedirect user ftId vfd = do
  let fileName = "redirect.yaml"
      file = CryptoFile fileName Nothing
      fInv = xftpFileInvitation fileName (fromIntegral $ B.length $ strEncode vfd) dummyFileDescr
  aFileId <- withAgent $ \a -> xftpSendDescription a (aUserId user) vfd (roundedFDCount 1)
  chSize <- asks $ fileChunkSize . config
  withStore' $ \db -> createSndFileTransferXFTP db user Nothing file fInv (AgentSndFileId aFileId) (Just ftId) chSize

dummyFileDescr :: FileDescr
dummyFileDescr = FileDescr {fileDescrText = "", fileDescrPartNo = 0, fileDescrComplete = False}

cancelFilesInProgress :: User -> [CIFileInfo] -> CM ()
cancelFilesInProgress user filesInfo = do
  let filesInfo' = filter (not . fileEnded) filesInfo
  (sfs, rfs) <- lift $ splitFTTypes <$> withStoreBatch (\db -> map (getFT db) filesInfo')
  forM_ rfs $ \RcvFileTransfer {fileId} -> lift (closeFileHandle fileId rcvFiles) `catchAllErrors` \_ -> pure ()
  lift . void . withStoreBatch' $ \db -> map (updateSndFileCancelled db) sfs
  lift . void . withStoreBatch' $ \db -> map (updateRcvFileCancelled db) rfs
  let xsfIds = mapMaybe (\(FileTransferMeta {fileId, xftpSndFile}, _) -> (,fileId) <$> xftpSndFile) sfs
      xrfIds = mapMaybe (\RcvFileTransfer {fileId, xftpRcvFile} -> (,fileId) <$> xftpRcvFile) rfs
  lift $ agentXFTPDeleteSndFilesRemote user xsfIds
  lift $ agentXFTPDeleteRcvFiles xrfIds
  where
    fileEnded CIFileInfo {fileStatus} = case fileStatus of
      Just (AFS _ status) -> ciFileEnded status
      Nothing -> True
    getFT :: DB.Connection -> CIFileInfo -> IO (Either ChatError FileTransfer)
    getFT db CIFileInfo {fileId} = runExceptT . withExceptT ChatErrorStore $ getFileTransfer db user fileId
    updateSndFileCancelled :: DB.Connection -> (FileTransferMeta, [SndFileTransfer]) -> IO ()
    updateSndFileCancelled db (FileTransferMeta {fileId}, sfts) = do
      updateFileCancelled db user fileId CIFSSndCancelled
      forM_ sfts $ \sft -> unless (sndFTEnded sft) $ updateSndFileStatus db sft FSCancelled
    updateRcvFileCancelled :: DB.Connection -> RcvFileTransfer -> IO ()
    updateRcvFileCancelled db ft@RcvFileTransfer {fileId} = do
      updateFileCancelled db user fileId CIFSRcvCancelled
      updateRcvFileStatus db fileId FSCancelled
      deleteRcvFileChunks db ft
    splitFTTypes :: [Either ChatError FileTransfer] -> ([(FileTransferMeta, [SndFileTransfer])], [RcvFileTransfer])
    splitFTTypes = foldr addFT ([], []) . rights
      where
        addFT f (sfs, rfs) = case f of
          FTSnd ft@FileTransferMeta {cancelled} sfts | not cancelled -> ((ft, sfts) : sfs, rfs)
          FTRcv ft@RcvFileTransfer {cancelled} | not cancelled -> (sfs, ft : rfs)
          _ -> (sfs, rfs)
    sndFTEnded SndFileTransfer {fileStatus} = fileStatus == FSCancelled || fileStatus == FSComplete

deleteFilesLocally :: [CIFileInfo] -> CM ()
deleteFilesLocally files =
  withFilesFolder $ \filesFolder ->
    liftIO . forM_ files $ \CIFileInfo {filePath} ->
      mapM_ (delete . (filesFolder </>)) filePath
  where
    delete :: FilePath -> IO ()
    delete fPath =
      removeFile fPath `catchAll` \_ ->
        removePathForcibly fPath `catchAll_` pure ()
    -- perform an action only if filesFolder is set (i.e. on mobile devices)
    withFilesFolder :: (FilePath -> CM ()) -> CM ()
    withFilesFolder action = asks filesFolder >>= readTVarIO >>= mapM_ action

deleteDirectCIs :: User -> Contact -> [CChatItem 'CTDirect] -> CM [ChatItemDeletion]
deleteDirectCIs user ct items = do
  let ciFilesInfo = mapMaybe (\(CChatItem _ ChatItem {file}) -> mkCIFileInfo <$> file) items
  deleteCIFiles user ciFilesInfo
  (errs, deletions) <- lift $ partitionEithers <$> withStoreBatch' (\db -> map (deleteItem db) items)
  unless (null errs) $ toView $ CEvtChatErrors errs
  pure deletions
  where
    deleteItem db (CChatItem md ci) = do
      deleteDirectChatItem db user ct ci
      pure $ contactDeletion md ct ci Nothing

deleteGroupCIs :: User -> GroupInfo -> Maybe GroupChatScopeInfo -> [CChatItem 'CTGroup] -> Maybe GroupMember -> UTCTime -> CM [ChatItemDeletion]
deleteGroupCIs user gInfo chatScopeInfo items byGroupMember_ deletedTs = do
  let ciFilesInfo = mapMaybe (\(CChatItem _ ChatItem {file}) -> mkCIFileInfo <$> file) items
  deleteCIFiles user ciFilesInfo
  (errs, deletions) <- lift $ partitionEithers <$> withStoreBatch' (\db -> map (deleteItem db) items)
  unless (null errs) $ toView $ CEvtChatErrors errs
  cxt <- chatStoreCxt
  deletions' <- case chatScopeInfo of
    Nothing -> pure deletions
    Just scopeInfo@GCSIMemberSupport {groupMember_} -> do
      let decStats = countDeletedUnreadItems groupMember_ deletions
      gInfo' <- withFastStore' $ \db -> updateGroupScopeUnreadStats db cxt user gInfo scopeInfo decStats
      pure $ map (updateDeletionGroupInfo gInfo') deletions
  pure deletions'
  where
    deleteItem :: DB.Connection -> CChatItem 'CTGroup -> IO ChatItemDeletion
    deleteItem db (CChatItem md ci) = do
      ci' <- case byGroupMember_ of
        Just m -> Just <$> updateGroupChatItemModerated db user gInfo ci m deletedTs
        Nothing -> Nothing <$ deleteGroupChatItem db user gInfo ci
      pure $ groupDeletion md gInfo chatScopeInfo ci ci'
    countDeletedUnreadItems :: Maybe GroupMember -> [ChatItemDeletion] -> (Int, Int, Int)
    countDeletedUnreadItems scopeMember_ = foldl' countItem (0, 0, 0)
      where
        countItem :: (Int, Int, Int) -> ChatItemDeletion -> (Int, Int, Int)
        countItem (!unread, !unanswered, !mentions) ChatItemDeletion {deletedChatItem}
          | aChatItemIsRcvNew deletedChatItem =
              let unread' = unread + 1
                  unanswered' = case (scopeMember_, aChatItemRcvFromMember deletedChatItem) of
                    (Just scopeMember, Just rcvFromMember)
                      | groupMemberId' rcvFromMember == groupMemberId' scopeMember -> unanswered + 1
                    _ -> unanswered
                  mentions' = if isACIUserMention deletedChatItem then mentions + 1 else mentions
               in (unread', unanswered', mentions')
          | otherwise = (unread, unanswered, mentions)
    updateDeletionGroupInfo :: GroupInfo -> ChatItemDeletion -> ChatItemDeletion
    updateDeletionGroupInfo gInfo' ChatItemDeletion {deletedChatItem, toChatItem} =
      ChatItemDeletion
        { deletedChatItem = updateACIGroupInfo gInfo' deletedChatItem,
          toChatItem = updateACIGroupInfo gInfo' <$> toChatItem
        }

updateACIGroupInfo :: GroupInfo -> AChatItem -> AChatItem
updateACIGroupInfo gInfo' = \case
  AChatItem SCTGroup dir (GroupChat _gInfo chatScopeInfo) ci ->
    AChatItem SCTGroup dir (GroupChat gInfo' chatScopeInfo) ci
  aci -> aci

deleteGroupMemberCIs :: User -> GroupInfo -> GroupMember -> CM ()
deleteGroupMemberCIs user gInfo member = do
  filesInfo <- withStore' $ \db -> deleteGroupMemberCIs_ db user gInfo member
  deleteCIFiles user filesInfo

deleteGroupMembersCIs :: User -> GroupInfo -> [GroupMember] -> CM ()
deleteGroupMembersCIs user gInfo members = do
  filesInfo <- withStore' $ \db -> fmap concat $ forM members $ deleteGroupMemberCIs_ db user gInfo
  deleteCIFiles user filesInfo

deleteGroupMemberCIs_ :: DB.Connection -> User -> GroupInfo -> GroupMember -> IO [CIFileInfo]
deleteGroupMemberCIs_ db user gInfo member = do
  fs <- getGroupMemberFileInfo db user gInfo member
  deleteMemberCIs db user gInfo member
  pure fs

deleteLocalCIs :: User -> NoteFolder -> [CChatItem 'CTLocal] -> Bool -> Bool -> CM ChatResponse
deleteLocalCIs user nf items byUser timed = do
  let ciFilesInfo = mapMaybe (\(CChatItem _ ChatItem {file}) -> mkCIFileInfo <$> file) items
  deleteFilesLocally ciFilesInfo
  (errs, deletions) <- lift $ partitionEithers <$> withStoreBatch' (\db -> map (deleteItem db) items)
  unless (null errs) $ toView $ CEvtChatErrors errs
  pure $ CRChatItemsDeleted user deletions byUser timed
  where
    deleteItem db (CChatItem md ci) = do
      deleteLocalChatItem db user nf ci
      pure $ ChatItemDeletion (nfItem md ci) Nothing
    nfItem :: MsgDirectionI d => SMsgDirection d -> ChatItem 'CTLocal d -> AChatItem
    nfItem md = AChatItem SCTLocal md (LocalChat nf)

deleteCIFiles :: User -> [CIFileInfo] -> CM ()
deleteCIFiles user filesInfo = do
  cancelFilesInProgress user filesInfo
  deleteFilesLocally filesInfo

markDirectCIsDeleted :: User -> Contact -> [CChatItem 'CTDirect] -> UTCTime -> CM [ChatItemDeletion]
markDirectCIsDeleted user ct items deletedTs = do
  let ciFilesInfo = mapMaybe (\(CChatItem _ ChatItem {file}) -> mkCIFileInfo <$> file) items
  cancelFilesInProgress user ciFilesInfo
  (errs, deletions) <- lift $ partitionEithers <$> withStoreBatch' (\db -> map (markDeleted db) items)
  unless (null errs) $ toView $ CEvtChatErrors errs
  pure deletions
  where
    markDeleted db (CChatItem md ci) = do
      ci' <- markDirectChatItemDeleted db user ct ci deletedTs
      pure $ contactDeletion md ct ci (Just ci')

markGroupCIsDeleted :: User -> GroupInfo -> Maybe GroupChatScopeInfo -> [CChatItem 'CTGroup] -> Maybe GroupMember -> UTCTime -> CM [ChatItemDeletion]
markGroupCIsDeleted user gInfo chatScopeInfo items byGroupMember_ deletedTs = do
  let ciFilesInfo = mapMaybe (\(CChatItem _ ChatItem {file}) -> mkCIFileInfo <$> file) items
  cancelFilesInProgress user ciFilesInfo
  (errs, deletions) <- lift $ partitionEithers <$> withStoreBatch' (\db -> map (markDeleted db) items)
  unless (null errs) $ toView $ CEvtChatErrors errs
  pure deletions
  where
    markDeleted db (CChatItem md ci) = do
      ci' <- markGroupChatItemDeleted db user gInfo ci byGroupMember_ deletedTs
      pure $ groupDeletion md gInfo chatScopeInfo ci (Just ci')

markGroupMemberCIsDeleted :: User -> GroupInfo -> GroupMember -> GroupMember -> CM ()
markGroupMemberCIsDeleted user gInfo member byGroupMember = do
  deletedTs <- liftIO getCurrentTime
  filesInfo <- withStore' $ \db -> markGroupMemberCIsDeleted_ db user gInfo member byGroupMember deletedTs
  cancelFilesInProgress user filesInfo

markGroupMembersCIsDeleted :: User -> GroupInfo -> [GroupMember] -> GroupMember -> CM ()
markGroupMembersCIsDeleted user gInfo members byGroupMember = do
  deletedTs <- liftIO getCurrentTime
  filesInfo <- withStore' $ \db -> fmap concat $ forM members $ \m -> markGroupMemberCIsDeleted_ db user gInfo m byGroupMember deletedTs
  cancelFilesInProgress user filesInfo

markGroupMemberCIsDeleted_ :: DB.Connection -> User -> GroupInfo -> GroupMember -> GroupMember -> UTCTime -> IO [CIFileInfo]
markGroupMemberCIsDeleted_ db user gInfo member byGroupMember deletedTs = do
  fs <- getGroupMemberFileInfo db user gInfo member
  markMemberCIsDeleted db user gInfo member byGroupMember deletedTs
  pure fs

groupDeletion :: MsgDirectionI d => SMsgDirection d -> GroupInfo -> Maybe GroupChatScopeInfo -> ChatItem 'CTGroup d -> Maybe (ChatItem 'CTGroup d) -> ChatItemDeletion
groupDeletion md g chatScopeInfo ci ci' = ChatItemDeletion (gItem ci) (gItem <$> ci')
  where
    gItem = AChatItem SCTGroup md (GroupChat g chatScopeInfo)

contactDeletion :: MsgDirectionI d => SMsgDirection d -> Contact -> ChatItem 'CTDirect d -> Maybe (ChatItem 'CTDirect d) -> ChatItemDeletion
contactDeletion md ct ci ci' = ChatItemDeletion (ctItem ci) (ctItem <$> ci')
  where
    ctItem = AChatItem SCTDirect md (DirectChat ct)

updateCallItemStatus :: User -> Contact -> Call -> WebRTCCallStatus -> Maybe MessageId -> CM ()
updateCallItemStatus user ct@Contact {contactId} Call {chatItemId} receivedStatus msgId_ = do
  aciContent_ <- callStatusItemContent user ct chatItemId receivedStatus
  forM_ aciContent_ $ \aciContent -> do
    timed_ <- callTimed ct aciContent
    updateDirectChatItemView user ct chatItemId aciContent False False timed_ msgId_
    forM_ (timed_ >>= timedDeleteAt') $
      startProximateTimedItemThread user (ChatRef CTDirect contactId Nothing, chatItemId)

updateDirectChatItemView :: User -> Contact -> ChatItemId -> ACIContent -> Bool -> Bool -> Maybe CITimed -> Maybe MessageId -> CM ()
updateDirectChatItemView user ct chatItemId (ACIContent msgDir ciContent) edited live timed_ msgId_ = do
  ci' <- withStore $ \db -> updateDirectChatItem db user ct chatItemId ciContent edited live timed_ msgId_
  toView $ CEvtChatItemUpdated user (AChatItem SCTDirect msgDir (DirectChat ct) ci')

callStatusItemContent :: User -> Contact -> ChatItemId -> WebRTCCallStatus -> CM (Maybe ACIContent)
callStatusItemContent user Contact {contactId} chatItemId receivedStatus = do
  CChatItem msgDir ChatItem {meta = CIMeta {updatedAt}, content} <-
    withStore $ \db -> getDirectChatItem db user contactId chatItemId
  ts <- liftIO getCurrentTime
  let callDuration :: Int = nominalDiffTimeToSeconds (ts `diffUTCTime` updatedAt) `div'` 1
      callStatus = case content of
        CISndCall st _ -> Just st
        CIRcvCall st _ -> Just st
        _ -> Nothing
      newState_ = case (callStatus, receivedStatus) of
        (Just CISCallProgress, WCSConnected) -> Nothing -- if call in-progress received connected -> no change
        (Just CISCallProgress, WCSDisconnected) -> Just (CISCallEnded, callDuration) -- calculate in-progress duration
        (Just CISCallProgress, WCSFailed) -> Just (CISCallEnded, callDuration) -- whether call disconnected or failed
        (Just CISCallPending, WCSDisconnected) -> Just (CISCallMissed, 0)
        (Just CISCallEnded, _) -> Nothing -- if call already ended or failed -> no change
        (Just CISCallError, _) -> Nothing
        (Just _, WCSConnecting) -> Just (CISCallNegotiated, 0)
        (Just _, WCSConnected) -> Just (CISCallProgress, 0) -- if call ended that was never connected, duration = 0
        (Just _, WCSDisconnected) -> Just (CISCallEnded, 0)
        (Just _, WCSFailed) -> Just (CISCallError, 0)
        (Nothing, _) -> Nothing -- some other content - we should never get here, but no exception is thrown
  pure $ aciContent msgDir <$> newState_
  where
    aciContent :: forall d. SMsgDirection d -> (CICallStatus, Int) -> ACIContent
    aciContent msgDir (callStatus', duration) = case msgDir of
      SMDSnd -> ACIContent SMDSnd $ CISndCall callStatus' duration
      SMDRcv -> ACIContent SMDRcv $ CIRcvCall callStatus' duration

-- mobile clients use file paths relative to app directory (e.g. for the reason ios app directory changes on updates),
-- so we have to differentiate between the file path stored in db and communicated with frontend, and the file path
-- used during file transfer for actual operations with file system
toFSFilePath :: FilePath -> CM' FilePath
toFSFilePath f =
  maybe f (</> f) <$> (chatReadVar' filesFolder)

setFileToEncrypt :: RcvFileTransfer -> CM RcvFileTransfer
setFileToEncrypt ft@RcvFileTransfer {fileId} = do
  cfArgs <- atomically . CF.randomArgs =<< asks random
  withStore' $ \db -> setFileCryptoArgs db fileId cfArgs
  pure (ft :: RcvFileTransfer) {cryptoArgs = Just cfArgs}

receiveFile' :: User -> RcvFileTransfer -> Bool -> Maybe Bool -> Maybe FilePath -> CM ChatResponse
receiveFile' user ft userApprovedRelays rcvInline_ filePath_ = do
  (CRRcvFileAccepted user <$> acceptFileReceive user ft userApprovedRelays rcvInline_ filePath_) `catchAllErrors` processError
  where
    -- TODO AChatItem in Cancelled events
    processError e
      | rctFileCancelled e = pure $ CRRcvFileAcceptedSndCancelled user ft
      | otherwise = throwError e

receiveFileEvt' :: User -> RcvFileTransfer -> Bool -> Maybe Bool -> Maybe FilePath -> CM ChatEvent
receiveFileEvt' user ft userApprovedRelays rcvInline_ filePath_ = do
  (CEvtRcvFileAccepted user <$> acceptFileReceive user ft userApprovedRelays rcvInline_ filePath_) `catchAllErrors` processError
  where
    -- TODO AChatItem in Cancelled events
    processError e
      | rctFileCancelled e = pure $ CEvtRcvFileAcceptedSndCancelled user ft
      | otherwise = throwError e

rctFileCancelled :: ChatError -> Bool
rctFileCancelled = \case
  ChatErrorAgent (SMP _ SMP.AUTH) _ _ -> True
  ChatErrorAgent (CONN DUPLICATE _) _ _ -> True
  _ -> False

acceptFileReceive :: User -> RcvFileTransfer -> Bool -> Maybe Bool -> Maybe FilePath -> CM AChatItem
acceptFileReceive user@User {userId} RcvFileTransfer {fileId, xftpRcvFile, fileInvitation = FileInvitation {fileName = fName, fileConnReq, fileInline, fileSize}, fileStatus, grpMemberId, cryptoArgs} userApprovedRelays rcvInline_ filePath_ = do
  unless (fileStatus == RFSNew) $ case fileStatus of
    RFSCancelled _ -> throwChatError $ CEFileCancelled fName
    _ -> throwChatError $ CEFileAlreadyReceiving fName
  cxt <- chatStoreCxt
  case (xftpRcvFile, fileConnReq) of
    -- XFTP
    (Just XFTPRcvFile {userApprovedRelays = approvedBeforeReady}, _) -> do
      let userApproved = approvedBeforeReady || userApprovedRelays
      filePath <- getRcvFilePath fileId filePath_ fName False
      (ci, rfd) <- withStore $ \db -> do
        -- marking file as accepted and reading description in the same transaction
        -- to prevent race condition with appending description
        ci <- xftpAcceptRcvFT db cxt user fileId filePath userApproved
        rfd <- getRcvFileDescrByRcvFileId db fileId
        pure (ci, rfd)
      receiveViaCompleteFD user fileId rfd fileSize userApproved cryptoArgs
      pure ci
    (Nothing, Just _fileConnReq) -> throwChatError $ CEException "accepting file via a separate connection is deprecated"
    -- group & direct file protocol
    _ -> do
      chatRef <- withStore $ \db -> getChatRefByFileId db user fileId
      case (chatRef, grpMemberId) of
        (ChatRef CTDirect contactId _, Nothing) -> do
          ct <- withStore $ \db -> getContact db cxt user contactId
          acceptFile $ \msg -> void $ sendDirectContactMessage user ct msg
        (ChatRef CTGroup groupId _, Just memId) -> do
          GroupMember {activeConn} <- withStore $ \db -> getGroupMember db cxt user groupId memId
          case activeConn of
            Just conn -> do
              acceptFile $ \msg -> void $ sendDirectMemberMessage conn msg groupId
            _ -> throwChatError $ CEFileInternal "member connection not active"
        _ -> throwChatError $ CEFileInternal "invalid chat ref for file transfer"
  where
    acceptFile :: (ChatMsgEvent 'Json -> CM ()) -> CM AChatItem
    acceptFile send = do
      filePath <- getRcvFilePath fileId filePath_ fName True
      inline <- receiveInline
      cxt <- chatStoreCxt
      if
        | inline -> do
            -- accepting inline
            (ci, sharedMsgId) <- withStore $ \db ->
              liftM2 (,) (acceptRcvInlineFT db cxt user fileId filePath) (getSharedMsgIdByFileId db userId fileId)
            send $ XFileAcptInv sharedMsgId Nothing fName
            pure ci
        | fileInline == Just IFMSent -> throwChatError $ CEFileAlreadyReceiving fName
        | otherwise -> throwChatError $ CEException "accepting file via a separate connection is deprecated"
    receiveInline :: CM Bool
    receiveInline = do
      ChatConfig {fileChunkSize, inlineFiles = InlineFilesConfig {receiveChunks, offerChunks}} <- asks config
      pure $
        rcvInline_ /= Just False
          && fileInline == Just IFMOffer
          && ( fileSize <= fileChunkSize * receiveChunks
                || (rcvInline_ == Just True && fileSize <= fileChunkSize * offerChunks)
             )

receiveViaCompleteFD :: User -> FileTransferId -> RcvFileDescr -> Integer -> Bool -> Maybe CryptoFileArgs -> CM ()
receiveViaCompleteFD user fileId RcvFileDescr {fileDescrText, fileDescrComplete} expectedFileSize userApprovedRelays cfArgs =
  when fileDescrComplete $ do
    rd <- parseFileDescription fileDescrText
    let FD.ValidFileDescription FD.FileDescription {size = FD.FileSize encSize, redirect} = rd
        redirectSize = maybe 0 (\FD.RedirectFileInfo {size = FD.FileSize s} -> toInteger s) redirect
        -- for a redirect, encSize is the description blob and redirectSize the final file; take the larger
        rcvSize = max (toInteger encSize) redirectSize
        -- 10 MB margin: encryption and chunk-size rounding make the transfer larger than the advertised size
        maxRcvSize = min expectedFileSize (toInteger FD.maxFileSizeHard) + toInteger (FD.mb 10 :: Int64)
    when (rcvSize > maxRcvSize) $ throwChatError $ CEFileRcvChunk "declared file size exceeds the file invitation size"
    if userApprovedRelays
      then receive' rd True
      else do
        let srvs = fileDescrServers rd
        unknownSrvs <- getUnknownSrvs srvs
        let approved = null unknownSrvs
        ifM
          ((approved ||) <$> ipProtectedForSrvs srvs)
          (receive' rd approved)
          (relaysNotApproved unknownSrvs)
  where
    receive' :: ValidFileDescription 'FRecipient -> Bool -> CM ()
    receive' rd approved = do
      aFileId <- withAgent $ \a -> xftpReceiveFile a (aUserId user) rd cfArgs approved
      startReceivingFile user fileId
      withStore' $ \db -> updateRcvFileAgentId db fileId (Just $ AgentRcvFileId aFileId)
    getUnknownSrvs :: [XFTPServer] -> CM [XFTPServer]
    getUnknownSrvs srvs = do
      knownSrvs <- L.map protoServer' <$> getKnownAgentServers SPXFTP user
      pure $ filter (`notElem` knownSrvs) srvs
    ipProtectedForSrvs :: [XFTPServer] -> CM Bool
    ipProtectedForSrvs srvs = do
      netCfg <- lift getNetworkConfig
      pure $ all (ipAddressProtected netCfg) srvs
    relaysNotApproved :: [XFTPServer] -> CM ()
    relaysNotApproved unknownSrvs = do
      aci_ <- resetRcvCIFileStatus user fileId CIFSRcvInvitation
      forM_ aci_ $ \aci -> do
        cleanupACIFile aci
        toView $ CEvtChatItemUpdated user aci
      throwChatError $ CEFileNotApproved fileId unknownSrvs

cleanupACIFile :: AChatItem -> CM ()
cleanupACIFile (AChatItem _ _ _ ChatItem {file = Just CIFile {fileSource = Just CryptoFile {filePath}}}) = do
  fsFilePath <- lift $ toFSFilePath filePath
  removeFile fsFilePath `catchAllErrors` \_ -> pure ()
cleanupACIFile _ = pure ()

getKnownAgentServers :: (ProtocolTypeI p, UserProtocol p) => SProtocolType p -> User -> CM (NonEmpty (ServerCfg p))
getKnownAgentServers p user = do
  as <- asks randomAgentServers
  withStore $ \db -> do
    opDomains <- operatorDomains . serverOperators <$> getServerOperators db
    srvs <- liftIO $ getProtocolServers db p user
    pure $ useServerCfgs p as opDomains srvs

protoServer' :: ServerCfg p -> ProtocolServer p
protoServer' ServerCfg {server} = protoServer server

getNetworkConfig :: CM' NetworkConfig
getNetworkConfig = withAgent' $ liftIO . getFastNetworkConfig

resetRcvCIFileStatus :: User -> FileTransferId -> CIFileStatus 'MDRcv -> CM (Maybe AChatItem)
resetRcvCIFileStatus user fileId ciFileStatus = do
  cxt <- chatStoreCxt
  withStore $ \db -> do
    liftIO $ do
      updateCIFileStatus db user fileId ciFileStatus
      updateRcvFileStatus db fileId FSNew
      updateRcvFileAgentId db fileId Nothing
    lookupChatItemByFileId db cxt user fileId

receiveViaURI :: User -> FileDescriptionURI -> CryptoFile -> CM RcvFileTransfer
receiveViaURI user@User {userId} FileDescriptionURI {description} cf@CryptoFile {cryptoArgs} = do
  fileId <- withStore $ \db -> createRcvStandaloneFileTransfer db userId cf fileSize chunkSize
  -- currently the only use case is user migrating via their configured servers, so we pass approvedRelays = True
  aFileId <- withAgent $ \a -> xftpReceiveFile a (aUserId user) description cryptoArgs True
  withStore $ \db -> do
    liftIO $ do
      updateRcvFileStatus db fileId FSConnected
      updateCIFileStatus db user fileId $ CIFSRcvTransfer 0 1
      updateRcvFileAgentId db fileId (Just $ AgentRcvFileId aFileId)
    getRcvFileTransfer db user fileId
  where
    FD.ValidFileDescription FD.FileDescription {size = FD.FileSize fileSize, chunkSize = FD.FileSize chunkSize} = description

startReceivingFile :: User -> FileTransferId -> CM ()
startReceivingFile user fileId = do
  cxt <- chatStoreCxt
  ci <- withStore $ \db -> do
    liftIO $ updateRcvFileStatus db fileId FSConnected
    liftIO $ updateCIFileStatus db user fileId $ CIFSRcvTransfer 0 1
    getChatItemByFileId db cxt user fileId
  toView $ CEvtRcvFileStart user ci

getRcvFilePath :: FileTransferId -> Maybe FilePath -> String -> Bool -> CM FilePath
getRcvFilePath fileId fPath_ fn keepHandle = case fPath_ of
  Nothing ->
    chatReadVar filesFolder >>= \case
      Nothing -> do
        defaultFolder <- lift getDefaultFilesFolder
        fPath <- liftIO $ defaultFolder `uniqueCombine` fn
        createEmptyFile fPath $> fPath
      Just filesFolder -> do
        fPath <- liftIO $ filesFolder `uniqueCombine` fn
        createEmptyFile fPath
        pure $ takeFileName fPath
  Just fPath ->
    ifM
      (doesDirectoryExist fPath)
      (createInPassedDirectory fPath)
      $ ifM
        (doesFileExist fPath)
        (throwChatError $ CEFileAlreadyExists fPath)
        (createEmptyFile fPath $> fPath)
  where
    createInPassedDirectory :: FilePath -> CM FilePath
    createInPassedDirectory fPathDir = do
      fPath <- liftIO $ fPathDir `uniqueCombine` fn
      createEmptyFile fPath $> fPath
    createEmptyFile :: FilePath -> CM ()
    createEmptyFile fPath = emptyFile `catchThrow` (ChatError . CEFileWrite fPath . show)
      where
        emptyFile :: CM ()
        emptyFile
          | keepHandle = do
              h <- getFileHandle fileId fPath rcvFiles AppendMode
              liftIO $ B.hPut h "" >> hFlush h
          | otherwise = liftIO $ B.writeFile fPath ""

-- TODO [short links]
-- Please note:
-- - the connection here is created as ConnNew, even though when joining it is created as ConnPrepared.
--   (changing it is risky, as there may be existing "prepared" connections that were not accepted in ConnNew status).
-- - after accepted, the status is changed by this func caller to ConnSndReady if it is sndSecure, and not changed otherwise - joined changed to ConnJoined in this case.
-- - xContactId is set on the contact at the first acceptance attempt, not after accept success, which prevents profile updates after such attempt.
--   It may be reasonable to set it when contact is first prepared, but then we can't use it to ignore requests after acceptance,
--   and it may lead to race conditions with XInfo events.
acceptContactRequest :: NetworkRequestMode -> User -> UserContactRequest -> IncognitoEnabled -> CM (Contact, Connection, SndQueueSecured)
acceptContactRequest nm user@User {userId} UserContactRequest {agentInvitationId = AgentInvId invId, contactId_, cReqChatVRange, localDisplayName = cName, profileId, profile = cp, userContactLinkId_, xContactId, pqSupport} incognito = do
  subMode <- chatReadVar subscriptionMode
  let pqSup = PQSupportOn
      pqSup' = pqSup `CR.pqSupportAnd` pqSupport
  cxt <- chatStoreCxt
  let chatV = vr cxt `peerConnChatVersion` cReqChatVRange
  (ct, conn, incognitoProfile) <- case contactId_ of
    Nothing -> do
      incognitoProfile <- if incognito then Just . NewIncognito <$> liftIO generateRandomProfile else pure Nothing
      connId <- withAgent $ \a -> prepareConnectionToAccept a (aUserId user) True invId pqSup'
      (ct, conn) <- withStore' $ \db ->
        createContactFromRequest db user userContactLinkId_ connId chatV cReqChatVRange cName profileId cp xContactId incognitoProfile subMode pqSup' False
      pure (ct, conn, incognitoProfile)
    Just contactId -> do
      ct <- withFastStore $ \db -> getContact db cxt user contactId
      case contactConn ct of
        Nothing -> do
          incognitoProfile <- if incognito then Just . NewIncognito <$> liftIO generateRandomProfile else pure Nothing
          connId <- withAgent $ \a -> prepareConnectionToAccept a (aUserId user) True invId pqSup'
          currentTs <- liftIO getCurrentTime
          conn <- withStore' $ \db -> do
            forM_ xContactId $ \xcId -> setContactAcceptedXContactId db ct xcId
            createAcceptedContactConn db user userContactLinkId_ contactId connId chatV cReqChatVRange pqSup' incognitoProfile subMode currentTs
          pure (ct {activeConn = Just conn} :: Contact, conn, incognitoProfile)
        Just conn@Connection {customUserProfileId} -> do
          incognitoProfile <- forM customUserProfileId $ \pId -> withFastStore $ \db -> getProfileById db userId pId
          pure (ct, conn, ExistingIncognito <$> incognitoProfile)
  profileToSend <- presentUserBadge user incognitoProfile $ userProfileDirect user (fromIncognitoProfile <$> incognitoProfile) (Just ct) True
  dm <- encodeConnInfoPQ pqSup' chatV $ XInfo profileToSend
  (ct,conn,) <$> withAgent (\a -> acceptContact a nm (aUserId user) (aConnId conn) True invId dm pqSup' subMode)

acceptContactRequestAsync :: User -> Int64 -> Contact -> UserContactRequest -> Maybe IncognitoProfile -> CM Contact
acceptContactRequestAsync
  user
  uclId
  ct@Contact {contactId}
  UserContactRequest {agentInvitationId = AgentInvId cReqInvId, cReqChatVRange, xContactId, pqSupport = cReqPQSup}
  incognitoProfile = do
    subMode <- chatReadVar subscriptionMode
    profileToSend <- presentUserBadge user incognitoProfile $ userProfileDirect user (fromIncognitoProfile <$> incognitoProfile) (Just ct) True
    cxt <- chatStoreCxt
    let chatV = vr cxt `peerConnChatVersion` cReqChatVRange
    (cmdId, acId) <- prepareAgentAccept user True cReqInvId cReqPQSup
    currentTs <- liftIO getCurrentTime
    ct' <- withStore $ \db -> do
      forM_ xContactId $ \xcId -> liftIO $ setContactAcceptedXContactId db ct xcId
      Connection {connId} <- liftIO $ createAcceptedContactConn db user (Just uclId) contactId acId chatV cReqChatVRange cReqPQSup incognitoProfile subMode currentTs
      liftIO $ setCommandConnId db user cmdId connId
      getContact db cxt user contactId
    agentAcceptContactAsync cmdId acId True cReqInvId (XInfo profileToSend) cReqPQSup chatV subMode
    pure ct'

acceptGroupJoinRequestAsync :: User -> Int64 -> GroupInfo -> InvitationId -> VersionRangeChat -> Profile -> Maybe XContactId -> Maybe MemberId -> Maybe SharedMsgId -> GroupAcceptance -> GroupMemberRole -> Maybe IncognitoProfile -> Maybe MemberKey -> Maybe GroupMember -> CM GroupMember
acceptGroupJoinRequestAsync
  user@User {userId}
  uclId
  gInfo@GroupInfo {groupProfile, membership, businessChat}
  cReqInvId
  cReqChatVRange
  cReqProfile
  cReqXContactId_
  cReqMemberId_
  welcomeMsgId_
  gAccepted
  gLinkMemRole
  incognitoProfile
  memberKey_
  existingMem_ = do
    gVar <- asks random
    let initialStatus = acceptanceToStatus (memberAdmission groupProfile) gAccepted
    -- a roster-established privileged member attaches a connection to its existing record (keeping
    -- owner-authoritative role + key); everyone else is created fresh with the group-link role
    cxt <- chatStoreCxt
    (groupMemberId, memberId) <- case existingMem_ of
      Just m -> do
        -- refresh the hash placeholder name from the authenticated join profile; role + key stay roster-authoritative
        withStore $ \db -> do
          liftIO $ updateGroupMemberStatus db userId m initialStatus
          void $ updateMemberProfile db cxt user m cReqProfile
        pure (groupMemberId' m, memberId' m)
      Nothing -> withStore $ \db ->
        createJoiningMember db cxt gVar user gInfo cReqChatVRange cReqProfile cReqXContactId_ cReqMemberId_ welcomeMsgId_ gLinkMemRole initialStatus memberKey_
    let currentMemCount = fromIntegral $ currentMembers $ groupSummary gInfo
    let Profile {displayName} = userProfileInGroup user gInfo (fromIncognitoProfile <$> incognitoProfile)
        GroupMember {memberRole = userRole, memberId = userMemberId} = membership
        msg =
          XGrpLinkInv $
            GroupLinkInvitation
              { fromMember = MemberIdRole userMemberId userRole,
                fromMemberName = displayName,
                invitedMember = MemberIdRole memberId gLinkMemRole,
                groupProfile,
                accepted = Just gAccepted,
                business = businessChat,
                groupSize = Just currentMemCount
              }
    subMode <- chatReadVar subscriptionMode
    let chatV = vr cxt `peerConnChatVersion` cReqChatVRange
    (cmdId, acId) <- prepareAgentAccept user True cReqInvId PQSupportOff
    m <- withStore $ \db -> do
      liftIO $ createJoiningMemberConnection db user uclId (cmdId, acId) chatV cReqChatVRange groupMemberId subMode
      getGroupMemberById db cxt user groupMemberId
    agentAcceptContactAsync cmdId acId True cReqInvId msg PQSupportOff chatV subMode
    pure m

acceptGroupJoinSendRejectAsync :: User -> Int64 -> GroupInfo -> InvitationId -> VersionRangeChat -> Profile -> Maybe XContactId -> GroupRejectionReason -> CM GroupMember
acceptGroupJoinSendRejectAsync
  user
  uclId
  gInfo@GroupInfo {groupProfile, membership}
  cReqInvId
  cReqChatVRange
  cReqProfile
  cReqXContactId_
  rejectionReason = do
    gVar <- asks random
    cxt <- chatStoreCxt
    (groupMemberId, memberId) <- withStore $ \db ->
      createJoiningMember db cxt gVar user gInfo cReqChatVRange cReqProfile cReqXContactId_ Nothing Nothing GRObserver GSMemRejected Nothing
    let GroupMember {memberRole = userRole, memberId = userMemberId} = membership
        msg =
          XGrpLinkReject $
            GroupLinkRejection
              { fromMember = MemberIdRole userMemberId userRole,
                invitedMember = MemberIdRole memberId GRObserver,
                groupProfile,
                rejectionReason
              }
    subMode <- chatReadVar subscriptionMode
    let chatV = vr cxt `peerConnChatVersion` cReqChatVRange
    (cmdId, acId) <- prepareAgentAccept user False cReqInvId PQSupportOff
    m <- withStore $ \db -> do
      liftIO $ createJoiningMemberConnection db user uclId (cmdId, acId) chatV cReqChatVRange groupMemberId subMode
      getGroupMemberById db cxt user groupMemberId
    agentAcceptContactAsync cmdId acId False cReqInvId msg PQSupportOff chatV subMode
    pure m

acceptBusinessJoinRequestAsync :: User -> Int64 -> GroupInfo -> GroupMember -> UserContactRequest -> CM (GroupInfo, GroupMember)
acceptBusinessJoinRequestAsync
  user
  uclId
  gInfo@GroupInfo {membership = GroupMember {memberRole = userRole, memberId = userMemberId}}
  clientMember@GroupMember {groupMemberId, memberId}
  UserContactRequest {agentInvitationId = AgentInvId cReqInvId, cReqChatVRange, xContactId} = do
    cxt <- chatStoreCxt
    let userProfile@Profile {displayName, preferences} = fromLocalProfile $ profile' user
        -- TODO [short links] take groupPreferences from group info
        groupPreferences = maybe defaultBusinessGroupPrefs businessGroupPrefs preferences
        msg =
          XGrpLinkInv $
            GroupLinkInvitation
              { fromMember = MemberIdRole userMemberId userRole,
                fromMemberName = displayName,
                invitedMember = MemberIdRole memberId GRMember,
                groupProfile = businessGroupProfile userProfile groupPreferences,
                accepted = Just GAAccepted,
                -- This refers to the "title member" that defines the group name and profile.
                -- This coincides with fromMember to be current user when accepting the connecting user,
                -- but it will be different when inviting somebody else.
                business = Just $ BusinessChatInfo {chatType = BCBusiness, businessId = userMemberId, customerId = memberId, businessDomain = Nothing},
                groupSize = Just 1
              }
    subMode <- chatReadVar subscriptionMode
    let chatV = vr cxt `peerConnChatVersion` cReqChatVRange
    (cmdId, acId) <- prepareAgentAccept user True cReqInvId PQSupportOff
    withStore' $ \db -> do
      forM_ xContactId $ \xcId -> setBusinessChatAcceptedXContactId db gInfo xcId
      createJoiningMemberConnection db user uclId (cmdId, acId) chatV cReqChatVRange groupMemberId subMode
    agentAcceptContactAsync cmdId acId True cReqInvId msg PQSupportOff chatV subMode
    let cd = CDGroupSnd gInfo Nothing
    -- TODO [short links] move to profileContactRequest?
    createInternalChatItem user cd (CISndGroupE2EEInfo $ e2eInfoGroup gInfo) Nothing
    createGroupFeatureItems user cd CISndGroupFeature gInfo
    -- TODO [short links] get updated business chat group and member? (currently not used)
    pure (gInfo, clientMember)

acceptRelayJoinRequestAsync :: User -> Int64 -> GroupInfo -> GroupMember -> InvitationId -> VersionRangeChat -> ShortLinkContact -> CM (GroupInfo, GroupMember)
acceptRelayJoinRequestAsync
  user
  uclId
  gInfo
  _ownerMember@GroupMember {groupMemberId}
  cReqInvId
  cReqChatVRange
  relayLink = do
    ChatConfig {webPreviewConfig} <- asks config
    let webDomain_ = (\WebPreviewConfig {webDomain} -> webDomain) <$> webPreviewConfig
        msg = XGrpRelayAcpt relayLink RelayCapabilities {webDomain = webDomain_}
    subMode <- chatReadVar subscriptionMode
    cxt <- chatStoreCxt
    let chatV = vr cxt `peerConnChatVersion` cReqChatVRange
    (cmdId, acId) <- prepareAgentAccept user True cReqInvId PQSupportOff
    r <- withStore $ \db -> do
      liftIO $ createJoiningMemberConnection db user uclId (cmdId, acId) chatV cReqChatVRange groupMemberId subMode
      gInfo' <- liftIO $ updateRelayOwnStatusFromTo db gInfo RSInvited RSAccepted
      ownerMember' <- getGroupMemberById db cxt user groupMemberId
      pure (gInfo', ownerMember')
    agentAcceptContactAsync cmdId acId True cReqInvId msg PQSupportOff chatV subMode
    pure r

rejectRelayInvitationAsync
  :: User
  -> Int64
  -> StoreCxt
  -> GroupRelayInvitation
  -> InvitationId
  -> VersionRangeChat
  -> Int64
  -> RelayRejectionReason
  -> CM ()
rejectRelayInvitationAsync user uclId cxt groupRelayInv invId reqChatVRange initialDelay reason = do
  (_gInfo, ownerMember) <- withStore $ \db ->
    createRelayRequestGroup db cxt user groupRelayInv invId reqChatVRange initialDelay GSMemInvited RSRejected
  let GroupMember {groupMemberId} = ownerMember
      msg = XGrpRelayReject reason
  subMode <- chatReadVar subscriptionMode
  chatVR <- chatVersionRange
  let chatV = chatVR `peerConnChatVersion` reqChatVRange
  (cmdId, acId) <- prepareAgentAccept user False invId PQSupportOff
  withStore' $ \db ->
    createJoiningMemberConnection db user uclId (cmdId, acId) chatV reqChatVRange groupMemberId subMode
  agentAcceptContactAsync cmdId acId False invId msg PQSupportOff chatV subMode

businessGroupProfile :: Profile -> GroupPreferences -> GroupProfile
businessGroupProfile Profile {displayName, fullName, shortDescr, description, image} groupPreferences =
  GroupProfile {displayName, fullName, description, shortDescr, image, publicGroup = Nothing, groupPreferences = Just groupPreferences, memberAdmission = Nothing}

introduceToModerators :: StoreCxt -> User -> GroupInfo -> GroupMember -> CM ()
introduceToModerators cxt user gInfo@GroupInfo {groupId} m@GroupMember {memberRole, memberId} = do
  forM_ (memberConn m) $ \mConn -> do
    let msg =
          if maxVersion (memberChatVRange m) >= groupKnockingVersion
            then XGrpLinkAcpt GAPendingReview memberRole memberId
            else XMsgNew $ mcSimple (MCText pendingReviewMessage)
    void $ sendDirectMemberMessage mConn msg groupId
  modMs <- withStore' $ \db -> getGroupModerators db cxt user gInfo
  let rcpModMs = filter shouldIntroduceToMod modMs
  introduceMember user gInfo m rcpModMs (Just $ MSMember $ memberId' m)
  where
    shouldIntroduceToMod :: GroupMember -> Bool
    shouldIntroduceToMod mem =
      memberCurrent mem
        && groupMemberId' mem /= groupMemberId' m
        && maxVersion (memberChatVRange mem) >= groupKnockingVersion

introduceToAll :: StoreCxt -> User -> GroupInfo -> GroupMember -> CM ()
introduceToAll cxt user gInfo m = do
  (members, vector) <- withStore $ \db -> liftM2 (,) (liftIO $ getGroupMembers db cxt user gInfo) (getMemberRelationsVector db m)
  let recipients = filter (shouldIntroduce m vector) members
  introduceMember user gInfo m recipients Nothing

introduceToRemaining :: StoreCxt -> User -> GroupInfo -> GroupMember -> CM ()
introduceToRemaining cxt user gInfo m = do
  (members, vector) <- withStore $ \db -> liftM2 (,) (liftIO $ getGroupMembers db cxt user gInfo) (getMemberRelationsVector db m)
  let recipients = filter (shouldIntroduce m vector) members
  introduceMember user gInfo m recipients Nothing

shouldIntroduce :: GroupMember -> ByteString -> GroupMember -> Bool
shouldIntroduce m vec mem =
  memberCurrent mem
    && groupMemberId' mem /= groupMemberId' m
    && getRelation (indexInGroup mem) vec == MRNew

introduceMember :: User -> GroupInfo -> GroupMember -> [GroupMember] -> Maybe MsgScope -> CM ()
introduceMember _ _ GroupMember {activeConn = Nothing} _ _ = throwChatError $ CEInternalError "member connection not active"
introduceMember user gInfo@GroupInfo {groupId} toMember@GroupMember {activeConn = Just conn} introduceToMembers msgScope = do
  void . sendGroupMessage' user gInfo introduceToMembers $ XGrpMemNew (memberInfo gInfo toMember) msgScope
  sendIntroductions introduceToMembers
  where
    sendIntroductions reMembers = do
      updateToMemberVector reMembers
      updateReMembersVectors reMembers
      shuffledReMembers <- liftIO $ shuffleMembers reMembers
      if toMember `supportsVersion` batchSendVersion
        then do
          let events = map (memberIntroEvt gInfo) shuffledReMembers
          forM_ (L.nonEmpty events) $ \events' ->
            sendGroupMemberMessages user gInfo conn events'
        else forM_ shuffledReMembers $ \reMember ->
          void $ sendDirectMemberMessage conn (memberIntroEvt gInfo reMember) groupId
    updateToMemberVector :: [GroupMember] -> CM ()
    updateToMemberVector reMembers = do
      let relations = map (\GroupMember {indexInGroup} -> (indexInGroup, (IDReferencedIntroduced, MRIntroduced))) reMembers
      withStore' $ \db -> setMemberVectorNewRelations db toMember relations
    updateReMembersVectors :: [GroupMember] -> CM ()
    updateReMembersVectors reMembers = do
      let GroupMember {indexInGroup} = toMember
      withStore' $ \db -> setMembersVectorsNewRelation db reMembers indexInGroup IDSubjectIntroduced MRIntroduced
    shuffleMembers :: [GroupMember] -> IO [GroupMember]
    shuffleMembers reMembers = do
      let (admins, others) = partition isAdmin reMembers
          (admPics, admNoPics) = partition hasPicture admins
          (othPics, othNoPics) = partition hasPicture others
      mconcat <$> mapM shuffle [admPics, admNoPics, othPics, othNoPics]
      where
        isAdmin GroupMember {memberRole} = memberRole >= GRAdmin
        hasPicture GroupMember {memberProfile = LocalProfile {image}} = isJust image

memberIntroEvt :: GroupInfo -> GroupMember -> ChatMsgEvent 'Json
memberIntroEvt gInfo reMember =
  let mInfo = memberInfo gInfo reMember
      mRestrictions = memberRestrictions reMember
   in XGrpMemIntro mInfo mRestrictions

-- Forward the saved owner-signed roster verbatim (reusing its signed shared_msg_id), then the
-- blob chunks, so the recipient verifies the owner signature.
serveRoster :: User -> GroupInfo -> GroupMember -> CM ()
serveRoster user gInfo member =
  when (member `supportsVersion` groupRosterVersion) $ do
    cxt <- chatStoreCxt
    withStore' (\db -> getStoredGroupRoster db gInfo) >>= \case
      Just (ownerGMId, brokerTs, sm@SignedMsg {signedBody}, blob_, storedVer_) ->
        case J.eitherDecodeStrict' signedBody :: Either String (ChatMessage 'Json) of
          Left e -> logError $ "serveRoster: cannot decode saved roster message: " <> tshow e
          Right chatMsg@ChatMessage {msgId} ->
            withStore' (\db -> runExceptT $ getGroupMemberById db cxt user ownerGMId) >>= \case
              Right owner -> do
                let fwd = GrpMsgForward {fwdSender = FwdMember (memberId' owner) (memberShortenedName owner), fwdBrokerTs = brokerTs}
                sendFwdMemberMessage member fwd (VMSigned MSSVerified sm chatMsg)
                forM_ ((,) <$> msgId <*> blob_) $ \(sid, blob) ->
                  sendInlineBlobChunks user gInfo [member] sid blob
                -- record the blob's own stored version as served, not roster_version (the gate): a delta can
                -- advance the gate past the stored blob on a failed blob send, and recording the gate would
                -- over-claim what this member was actually served, suppressing legitimate catch-up
                forM_ storedVer_ $ \v -> withStore' $ \db -> setMemberRosterServedVersion db member v
              Left e -> logError $ "serveRoster: roster owner not found: " <> tshow e
      Nothing -> pure ()

-- Used in groups with relays to introduce moderators and above to a new member,
-- and to announce the new member to moderators and above.
-- This doesn't create introduction records in db, compared to above methods.
introduceInChannel :: StoreCxt -> User -> GroupInfo -> GroupMember -> CM ()
introduceInChannel _ _ _ GroupMember {activeConn = Nothing} = throwChatError $ CEInternalError "member connection not active"
introduceInChannel cxt user gInfo subscriber@GroupMember {activeConn = Just conn, indexInGroup = subscriberIdx} = do
  (owners, adminsMods) <- withStore' $ \db ->
    (,) <$> getGroupOwners db cxt user gInfo <*> getGroupAdminsMods db cxt user gInfo
  let modMs = owners <> adminsMods
  void $ sendGroupMessage' user gInfo modMs $ XGrpMemNew (memberInfo gInfo subscriber) Nothing
  withStore' $ \db ->
    setMemberVectorNewRelations db subscriber [(indexInGroup m, (IDSubjectIntroduced, MRIntroduced)) | m <- modMs]
  -- owner intros first so the joiner has the owner profile loaded before applying the saved roster (signed by the owner)
  sendIntros owners
  serveRoster user gInfo subscriber
  sendIntros adminsMods
  withStore' $ \db ->
    setMembersVectorsNewRelation db modMs subscriberIdx IDSubjectIntroduced MRIntroduced
  where
    sendIntros ms = forM_ (L.nonEmpty $ map (memberIntroEvt gInfo) ms) $ \evts ->
      sendGroupMemberMessages user gInfo conn evts

userProfileInGroup :: User -> GroupInfo -> Maybe Profile -> Profile
userProfileInGroup user g = userProfileInGroup' user (Just g)
{-# INLINE userProfileInGroup #-}

-- Nothing group ⇒ no redaction (e.g. joining via a link with no group profile yet).
userProfileInGroup' :: User -> Maybe GroupInfo -> Maybe Profile -> Profile
userProfileInGroup' User {profile = p} mg incognitoProfile =
  let p' = fromMaybe (fromLocalProfile p) incognitoProfile
   in maybe p' (\g -> redactedMemberProfile g (membership g) p') mg

memberInfo :: GroupInfo -> GroupMember -> MemberInfo
memberInfo g m@GroupMember {memberId, memberRole, memberProfile, memberPubKey, activeConn} =
  MemberInfo
    { memberId,
      memberRole,
      v = ChatVersionRange . peerChatVRange <$> activeConn,
      profile = redactedMemberProfile g m $ fromLocalProfile memberProfile,
      memberKey = MemberKey <$> memberPubKey
    }

redactedMemberProfile :: GroupInfo -> GroupMember -> Profile -> Profile
redactedMemberProfile g m Profile {displayName, fullName, shortDescr, description, image, contactLink = lnk, peerType, badge, contactDomain} =
  Profile {displayName, fullName, shortDescr = removePopopxLink True =<< shortDescr, description = removePopopxLink False =<< description, image, contactLink, preferences = Nothing, peerType, badge, contactDomain = redactedDomain}
  where
    contactLink = if allowPopopxLinks then lnk else Nothing
    redactedDomain = if allowDirect then (\d -> d {proof = Nothing} :: PopopxDomainClaim) <$> contactDomain else Nothing
    allowDirect = groupFeatureMemberAllowed SGFDirectMessages m g
    allowPopopxLinks = groupFeatureMemberAllowed SGFPopopxLinks m g && allowDirect
    removePopopxLink dropOnLink s
      | allowPopopxLinks = Just s
      | otherwise = case parseMaybeMarkdownList s of
          Nothing -> dropObfuscated
          Just fts
            | not (any ftIsPopopxLink fts) -> dropObfuscated
            | dropOnLink || T.null (T.strip kept) || hasObfuscatedPopopxLink kept -> Nothing
            | otherwise -> Just kept
            where
              kept = T.concat $ map (\(FormattedText _ t) -> t) $ filter (not . ftIsPopopxLink) fts
      where
        dropObfuscated = if hasObfuscatedPopopxLink s then Nothing else Just s

-- Roles carried by the roster; owners are on the link, not the roster.
isRosterRole :: GroupMemberRole -> Bool
isRosterRole r = r == GRMember || r == GRModerator || r == GRAdmin

isPrivilegedRole :: GroupMemberRole -> Bool
isPrivilegedRole r = r >= GRMember

-- Minimum role allowed to change a member's role from `from` to `to` (moderators only up to member; relay checked separately).
roleRequiredToChange :: GroupMemberRole -> GroupMemberRole -> GroupMemberRole
roleRequiredToChange from to
  | from <= GRMember && to <= GRMember = GRModerator
  | otherwise = maximum ([GRAdmin, from, to] :: [GroupMemberRole])

-- Drop non-privileged-role entries and de-duplicate by memberId, keeping the first.
-- Runs on the parsed roster blob.
validateGroupRoster :: [RosterMember] -> [RosterMember]
validateGroupRoster entries =
  dedup S.empty $ filter (\RosterMember {role} -> isRosterRole role) entries
  where
    dedup _ [] = []
    dedup seen (rm@RosterMember {memberId} : rms)
      | memberId `S.member` seen = dedup seen rms
      | otherwise = rm : dedup (S.insert memberId seen) rms

-- Privileged members without a known key are skipped (recipients can't verify them).
buildGroupRoster :: [GroupMember] -> [RosterMember]
buildGroupRoster mods = take maxGroupRosterSize $ mapMaybe rosterMember mods
  where
    rosterMember GroupMember {memberId, memberPubKey, memberRole}
      | isRosterRole memberRole = (\k -> RosterMember {memberId, key = MemberKey k, role = memberRole, privileges = 0}) <$> memberPubKey
      | otherwise = Nothing

sendHistory :: User -> GroupInfo -> GroupMember -> CM ()
sendHistory _ _ GroupMember {activeConn = Nothing} = throwChatError $ CEInternalError "member connection not active"
sendHistory user gInfo@GroupInfo {membership} m@GroupMember {activeConn = Just conn} =
  when (m `supportsVersion` batchSendVersion) $ do
    (errs, items) <- partitionEithers <$> withStore' (\db -> getGroupHistoryItems db user gInfo m 100)
    (errs', fwdMsgsByItem) <- partitionEithers <$> mapM (tryAllErrors . itemForwardMsgs) items
    let errors = map ChatErrorStore errs <> errs'
    unless (null errors) $ toView $ CEvtChatErrors errors
    -- signed items keep the author's original bytes/signature, unsigned are re-encoded; the welcome message
    -- (regular groups only; never channels) is an authored element -- all batch together in order.
    let fwdEls = map (uncurry encodeFwdElement) (concat fwdMsgsByItem)
    welcomeEl <- welcomeElement
    let (batches, dropped) = batchElements maxEncodedMsgLength (fwdEls <> maybe [] (: []) welcomeEl)
    when (dropped > 0) $ toView $ CEvtChatErrors [ChatError $ CEInternalError ("sendHistory: dropped " <> show dropped <> " oversized history messages")]
    forM_ batches $ \body ->
      void $ withAgent $ \a -> sendMessages a [(aConnId conn, PQEncOff, MsgFlags False, VRValue Nothing body)]
  where
    welcomeElement :: CM (Maybe ByteString)
    welcomeElement = case descrEvent_ of
      Just descr ->
        withStore' (\db -> getMemberJoinRequest db user gInfo m) >>= \case
          Just (_, Just _welcomeMsgId) -> pure Nothing
          _ -> do
            vr <- chatVersionRange
            sharedMsgId <- SharedMsgId <$> drgRandomBytes 24
            case encodeChatMessage maxEncodedMsgLength ChatMessage {chatVRange = vr, msgId = Just sharedMsgId, chatMsgEvent = descr} of
              ECMEncoded body -> pure $ Just (encodeBatchElement Nothing body)
              ECMLarge -> Nothing <$ toView (CEvtChatErrors [ChatError $ CEInternalError "sendHistory: welcome message too large"])
      Nothing -> pure Nothing
    descrEvent_ :: Maybe (ChatMsgEvent 'Json)
    descrEvent_
      -- in channels sendHistory runs on the relay, which cannot author XMsgNew (GRRelay < GRObserver);
      -- the welcome message reaches new members via the channel link data instead
      | useRelays' gInfo = Nothing
      | m `supportsVersion` groupHistoryIncludeWelcomeVersion = do
          let GroupInfo {groupProfile = GroupProfile {description}} = gInfo
          fmap (\descr -> XMsgNew $ mcSimple (MCText descr)) description
      | otherwise = Nothing
    itemForwardMsgs :: (CChatItem 'CTGroup, (Maybe SignedMsg, Maybe GroupMemberId)) -> CM [(GrpMsgForward, VerifiedMsg 'Json)]
    itemForwardMsgs (cci, (signedMsg_, signedByGMId_)) = case cci of
      (CChatItem SMDRcv ci@ChatItem {content = CIRcvMsgContent mc, file})
        | not (maybe False blockedByAdmin (chatItemRcvFromMember ci)) -> do
            fInvDescr_ <- join <$> forM file getRcvFileInvDescr
            -- channel items carry no from-member; a signed one falls back to the stored author (verified attribution)
            member_ <- maybe (resolveAuthor signedByGMId_) (pure . Just) (chatItemRcvFromMember ci)
            processContentItem member_ ci mc fInvDescr_
        | otherwise -> pure []
      (CChatItem SMDSnd ci@ChatItem {content = CISndMsgContent mc, file, meta = CIMeta {showGroupAsSender}}) -> do
        fInvDescr_ <- join <$> forM file getSndFileInvDescr
        let member_ = if showGroupAsSender && isNothing signedMsg_ then Nothing else Just membership
        processContentItem member_ ci mc fInvDescr_
      _ -> pure []
      where
        resolveAuthor :: Maybe GroupMemberId -> CM (Maybe GroupMember)
        resolveAuthor Nothing = pure Nothing
        resolveAuthor (Just gmId) = do
          cxt <- chatStoreCxt
          eitherToMaybe <$> withStore' (\db -> runExceptT $ getGroupMemberById db cxt user gmId)
        getRcvFileInvDescr :: CIFile 'MDRcv -> CM (Maybe (FileInvitation, RcvFileDescrText))
        getRcvFileInvDescr ciFile@CIFile {fileId, fileProtocol, fileStatus} = do
          expired <- fileExpired
          if fileProtocol /= FPXFTP || fileStatus == CIFSRcvCancelled || expired
            then pure Nothing
            else do
              rfd <- withStore $ \db -> getRcvFileDescrByRcvFileId db fileId
              pure $ invCompleteDescr ciFile rfd
        getSndFileInvDescr :: CIFile 'MDSnd -> CM (Maybe (FileInvitation, RcvFileDescrText))
        getSndFileInvDescr ciFile@CIFile {fileId, fileProtocol, fileStatus} = do
          expired <- fileExpired
          if fileProtocol /= FPXFTP || fileStatus == CIFSSndCancelled || expired
            then pure Nothing
            else do
              -- can also lookup in extra_xftp_file_descriptions, though it can be empty;
              -- would be best if snd file had a single rcv description for all members saved in files table
              rfd <- withStore $ \db -> getRcvFileDescrBySndFileId db fileId
              pure $ invCompleteDescr ciFile rfd
        fileExpired :: CM Bool
        fileExpired = do
          ttl <- asks $ rcvFilesTTL . agentConfig . config
          cutoffTs <- addUTCTime (-ttl) <$> liftIO getCurrentTime
          pure $ chatItemTs cci < cutoffTs
        invCompleteDescr :: CIFile d -> RcvFileDescr -> Maybe (FileInvitation, RcvFileDescrText)
        invCompleteDescr CIFile {fileName, fileSize} RcvFileDescr {fileDescrText, fileDescrComplete}
          | fileDescrComplete =
              let fInvDescr = FileDescr {fileDescrText = "", fileDescrPartNo = 0, fileDescrComplete = False}
                  fInv = xftpFileInvitation fileName fileSize fInvDescr
               in Just (fInv, fileDescrText)
          | otherwise = Nothing
        processContentItem :: Maybe GroupMember -> ChatItem 'CTGroup d -> MsgContent -> Maybe (FileInvitation, RcvFileDescrText) -> CM [(GrpMsgForward, VerifiedMsg 'Json)]
        processContentItem member_ ChatItem {formattedText, meta, quotedItem, mentions} mc fInvDescr_ =
          if isNothing fInvDescr_ && not (msgContentHasText mc)
            then pure []
            else do
              let CIMeta {itemTs, itemSharedMsgId, itemTimed, showGroupAsSender} = meta
                  quotedItemId_ = quoteItemId =<< quotedItem
                  fInv_ = fst <$> fInvDescr_
                  (mc', _, mentions') = updatedMentionNames mc formattedText mentions
                  mentions'' = M.map (\CIMention {memberId} -> MsgMention {memberId}) mentions'
                  -- for channel messages default chat version range to membership range
                  senderVRange = maybe (memberChatVRange' membership) memberChatVRange' member_
                  -- member_ is Nothing only for as-group unsigned items -> FwdChannel; otherwise attribute to the member
                  -- (the author for signed as-group items), so the recipient can reconstruct the binding and verify
                  fwdSender = maybe FwdChannel (\am -> FwdMember (memberId' am) (memberShortenedName am)) member_
                  fwd = GrpMsgForward {fwdSender, fwdBrokerTs = itemTs}
              -- signed items forward the author's original bytes so the signature stays valid; unsigned re-encode current content
              contentVM <- case signedMsg_ of
                Just sm@SignedMsg {signedBody}
                  | Right chatMsg <- (J.eitherDecodeStrict' signedBody :: Either String (ChatMessage 'Json)) ->
                      pure $ VMSigned MSSVerified sm chatMsg
                _ -> do
                  -- TODO [knocking] send history to other scopes too?
                  (chatMsgEvent, _) <- withStore $ \db -> prepareGroupMsg db user gInfo Nothing showGroupAsSender mc' mentions'' quotedItemId_ Nothing fInv_ itemTimed False
                  pure $ VMUnsigned ChatMessage {chatVRange = senderVRange, msgId = itemSharedMsgId, chatMsgEvent}
              fileDescrEvents <- case (snd <$> fInvDescr_, itemSharedMsgId) of
                (Just fileDescrText, Just msgId) -> do
                  partSize <- asks $ xftpDescrPartSize . config
                  let parts = splitFileDescr partSize fileDescrText
                  pure . L.toList $ L.map (XMsgFileDescr msgId) parts
                _ -> pure []
              let fileDescrVMs = map (VMUnsigned . ChatMessage senderVRange Nothing) fileDescrEvents
              pure $ map ((,) fwd) (contentVM : fileDescrVMs)

memberShortenedName :: GroupMember -> ContactName
memberShortenedName GroupMember {memberProfile = LocalProfile {displayName}}
  | T.length displayName <= 16 = displayName
  | otherwise = T.take 16 displayName `T.snoc` '…'

splitFileDescr :: Int -> RcvFileDescrText -> NonEmpty FileDescr
splitFileDescr partSize rfdText = splitParts 1 rfdText
  where
    splitParts partNo remText =
      let (part, rest) = T.splitAt partSize remText
          complete = T.null rest
          fileDescr = FileDescr {fileDescrText = part, fileDescrPartNo = partNo, fileDescrComplete = complete}
       in if complete
            then fileDescr :| []
            else fileDescr <| splitParts (partNo + 1) rest

setGroupLinkData' :: NetworkRequestMode -> User -> GroupInfo -> CM (Maybe GroupLink)
setGroupLinkData' nm user gInfo =
  withFastStore' (\db -> runExceptT $ getGroupLink db user gInfo) >>= \case
    Right gLink@GroupLink {shortLinkDataSet}
      | shortLinkDataSet -> Just <$> setGroupLinkData nm user gInfo gLink
    _ -> pure Nothing

setGroupLinkData :: NetworkRequestMode -> User -> GroupInfo -> GroupLink -> CM GroupLink
setGroupLinkData nm user gInfo gLink = do
  cxt <- chatStoreCxt
  (conn, groupRelays) <- withFastStore $ \db ->
    (,) <$> getGroupLinkConnection db cxt user gInfo <*> liftIO (getPublishableGroupRelays db cxt user gInfo)
  let (userLinkData, crClientData) = groupLinkData gInfo gLink groupRelays
      linkType = if useRelays' gInfo then CCTChannel else CCTGroup
  sLnk <- shortenShortLink' . setShortLinkType_ linkType =<< withAgent (\a -> setConnShortLink a nm (aConnId conn) SCMContact userLinkData (Just crClientData))
  withFastStore' $ \db -> setGroupLinkShortLink db gLink sLnk

setGroupLinkDataAsync :: User -> GroupInfo -> GroupLink -> CM ()
setGroupLinkDataAsync user gInfo gLink = do
  cxt <- chatStoreCxt
  (conn, groupRelays) <- withStore $ \db ->
    (,) <$> getGroupLinkConnection db cxt user gInfo <*> liftIO (getPublishableGroupRelays db cxt user gInfo)
  let (userLinkData, crClientData) = groupLinkData gInfo gLink groupRelays
  setAgentConnShortLinkAsync user conn userLinkData (Just crClientData)

connectToRelayAsync :: User -> GroupInfo -> ShortLinkContact -> CM ()
connectToRelayAsync user gInfo relayLink = do
  cxt <- chatStoreCxt
  gVar <- asks random
  relayMember@GroupMember {activeConn} <- withFastStore $ \db -> getCreateRelayForMember db cxt gVar user gInfo relayLink
  case activeConn of
    Just _ -> pure ()
    Nothing -> do
      subMode <- chatReadVar subscriptionMode
      newConnIds <- getAgentConnShortLinkAsync user CFGetRelayDataJoin Nothing relayLink
      withFastStore' $ \db -> createRelayMemberConnectionAsync db user gInfo relayMember relayLink newConnIds subMode

updatePublicGroupData :: User -> GroupInfo -> CM GroupInfo
updatePublicGroupData user gInfo
  | useRelays' gInfo && memberRole' (membership gInfo) == GROwner = do
      cxt <- chatStoreCxt
      (gInfo', gLink) <- withStore $ \db -> do
        gInfo' <- updatePublicMemberCount db cxt user gInfo
        gLink <- getGroupLink db user gInfo'
        pure (gInfo', gLink)
      setGroupLinkDataAsync user gInfo' gLink
      pure gInfo'
  | useRelays' gInfo && isRelay (membership gInfo) = do
      cxt <- chatStoreCxt
      withStore $ \db -> updatePublicMemberCount db cxt user gInfo
  | otherwise = pure gInfo

-- must not resolve names here: a background link-data refresh would leak channel membership to the resolver
updateGroupFromLinkData :: User -> GroupInfo -> GroupShortLinkData -> Maybe PopopxDomain -> CM (GroupInfo, Bool)
updateGroupFromLinkData user gInfo@GroupInfo {groupProfile = p, groupSummary = GroupSummary {publicMemberCount = localCount}} GroupShortLinkData {groupProfile, publicGroupData} resolvedDomain_
  | profileChanged || countChanged || verifyResolved = do
      cxt <- chatStoreCxt
      withStore $ \db -> do
        g <- if profileChanged then updateGroupProfile db user gInfo groupProfile else pure gInfo
        g' <- case publicGroupData of
          Just PublicGroupData {publicMemberCount} | countChanged ->
            setPublicMemberCount db cxt user g publicMemberCount
          _ -> pure g
        g'' <- if verifyResolved then liftIO $ setGroupDomainVerified db user g' True else pure g'
        pure (g'', profileChanged)
  | otherwise = pure (gInfo, False)
  where
    profileChanged = p /= groupProfile
    countChanged = case publicGroupData of
      Just PublicGroupData {publicMemberCount} -> Just publicMemberCount /= localCount
      _ -> False
    groupClaim GroupProfile {publicGroup} = claimDomain <$> (publicGroup >>= publicGroupAccess >>= groupDomainClaim)
    newClaim = groupClaim groupProfile
    verifyResolved = isJust resolvedDomain_ && resolvedDomain_ == newClaim

updateContactFromLinkData :: User -> Contact -> Profile -> CM Contact
updateContactFromLinkData user ct@Contact {profile = profile@LocalProfile {contactDomain = prevClaim, contactDomainVerified}} linkProfile@Profile {contactDomain = newClaim}
  | profileChanged || verifyChanged = do
      cxt <- chatStoreCxt
      withFastStore $ \db -> do
        ct' <- updateContactProfile db cxt user ct linkProfile
        if verifyChanged then liftIO $ setContactDomainVerified db user ct' True else pure ct'
  | otherwise = pure ct
  where
    profileChanged = fromLocalProfile profile /= linkProfile
    claimChanged = (claimDomain <$> prevClaim) /= (claimDomain <$> newClaim)
    verifyChanged = contactDomainVerified /= Just True || claimChanged

-- TODO [relays] owner: set owners on updating link data (multi-owner)
groupLinkData :: GroupInfo -> GroupLink -> [GroupRelay] -> (UserConnLinkData 'CMContact, CRClientData)
groupLinkData gInfo@GroupInfo {groupProfile, groupSummary = GroupSummary {publicMemberCount}, membership = GroupMember {memberId}, groupKeys} GroupLink {groupLinkId} groupRelays =
  let direct = not $ useRelays' gInfo
      relays = mapMaybe (\GroupRelay {relayLink} -> relayLink) groupRelays
      publicGroupData_ = PublicGroupData <$> publicMemberCount
      userData = encodeShortLinkData $ GroupShortLinkData {groupProfile, publicGroupData = publicGroupData_}
      owners = case groupKeys of
        Just GroupKeys {groupRootKey = GRKPrivate rootPrivKey, memberPrivKey} ->
          let ownerId = unMemberId memberId
              ownerKey = C.publicKey memberPrivKey
              authOwnerSig = C.sign' rootPrivKey (ownerId <> C.encodePubKey ownerKey)
           in [OwnerAuth {ownerId, ownerKey, authOwnerSig}]
        _ -> []
      userLinkData = UserContactLinkData UserContactData {direct, owners, relays, userData}
      crClientData = encodeJSON $ CRDataGroup groupLinkId
   in (userLinkData, crClientData)

restoreShortLink' :: ConnShortLink m -> CM (ConnShortLink m)
restoreShortLink' l = (`restoreShortLink` l) <$> asks (shortLinkPresetServers . config)

getShortLinkConnReq' :: NetworkRequestMode -> User -> ConnShortLink m -> CM (FixedLinkData m, ConnLinkData m)
getShortLinkConnReq' nm user l = do
  l' <- restoreShortLink' l
  withAgent $ \a -> getConnShortLink a nm (aUserId user) l'

getShortLinkConnReq :: NetworkRequestMode -> User -> ConnShortLink m -> CM (FixedLinkData m, ConnLinkData m)
getShortLinkConnReq nm user l = do
  (fd, cData) <- getShortLinkConnReq' nm user l
  case cData of
    ContactLinkData _ UserContactData {direct, relays}
      | not supported -> throwChatError CEUnsupportedConnReq
      where
        supported = direct || not (null relays)
    _ -> pure ()
  pure (fd, cData)

encodeShortLinkData :: J.ToJSON a => a -> UserLinkData
encodeShortLinkData d =
  let s = LB.toStrict $ J.encode d
      -- 10kb size limit for compression to be used is based on 13784 limit for link data
      -- and the space reserved for the other fields in ConnLinkData encoding (most of these fields are currently unused).
      s'
        | B.length s > 10240 = B.cons 'X' $ Z1.compress compressionLevel s
        | otherwise = s
   in UserLinkData s'

decodeLinkUserData :: J.FromJSON a => ConnLinkData c -> IO (Maybe a)
decodeLinkUserData cData
  | B.null s = pure Nothing
  | B.head s == 'X' = case limitDecompress' maxDecompressedMsgLength $ B.drop 1 s of
      Left e -> Nothing <$ logError ("Error decompressing link data: " <> tshow e)
      Right s' -> decode s'
  | otherwise = decode s
  where
    decode s' = case J.eitherDecodeStrict s' of
      Right d -> pure $ Just d
      Left e -> Nothing <$ logError ("Error decoding link data: " <> tshow e)
    s = linkUserData' cData

shortenShortLink' :: ConnShortLink m -> CM (ConnShortLink m)
shortenShortLink' l = (`shortenShortLink` l) <$> asks (shortLinkPresetServers . config)

shortenCreatedLink :: CreatedConnLink m -> CM (CreatedConnLink m)
shortenCreatedLink (CCLink cReq sLnk) = CCLink cReq <$> mapM shortenShortLink' sLnk

deleteGroupLink' :: User -> GroupInfo -> CM ()
deleteGroupLink' user gInfo = do
  cxt <- chatStoreCxt
  conn <- withStore $ \db -> getGroupLinkConnection db cxt user gInfo
  deleteGroupLink_ user gInfo conn

deleteGroupLinkIfExists :: User -> GroupInfo -> CM ()
deleteGroupLinkIfExists user gInfo = do
  cxt <- chatStoreCxt
  conn_ <- eitherToMaybe <$> withStore' (\db -> runExceptT $ getGroupLinkConnection db cxt user gInfo)
  mapM_ (deleteGroupLink_ user gInfo) conn_

deleteGroupLink_ :: User -> GroupInfo -> Connection -> CM ()
deleteGroupLink_ user gInfo conn = do
  deleteAgentConnectionAsync $ aConnId conn
  withStore' $ \db -> deleteGroupLink db user gInfo

startProximateTimedItemThread :: User -> (ChatRef, ChatItemId) -> UTCTime -> CM ()
startProximateTimedItemThread user itemRef deleteAt = do
  interval <- asks (cleanupManagerInterval . config)
  ts <- liftIO getCurrentTime
  when (diffUTCTime deleteAt ts <= interval) $
    startTimedItemThread user itemRef deleteAt

startTimedItemThread :: User -> (ChatRef, ChatItemId) -> UTCTime -> CM ()
startTimedItemThread user itemRef deleteAt = do
  itemThreads <- asks timedItemThreads
  threadTVar_ <- atomically $ do
    exists <- TM.member itemRef itemThreads
    if not exists
      then do
        threadTVar <- newTVar Nothing
        TM.insert itemRef threadTVar itemThreads
        pure $ Just threadTVar
      else pure Nothing
  forM_ threadTVar_ $ \threadTVar -> do
    tId <- mkWeakThreadId =<< deleteTimedItem user itemRef deleteAt `forkFinally` const (atomically $ TM.delete itemRef itemThreads)
    atomically $ writeTVar threadTVar (Just tId)

deleteTimedItem :: User -> (ChatRef, ChatItemId) -> UTCTime -> CM ()
deleteTimedItem user (ChatRef cType chatId scope, itemId) deleteAt = do
  ts <- liftIO getCurrentTime
  liftIO $ threadDelay' $ diffToMicroseconds $ diffUTCTime deleteAt ts
  lift waitChatStartedAndActivated
  cxt <- chatStoreCxt
  case cType of
    CTDirect -> do
      (ct, ci) <- withStore $ \db -> (,) <$> getContact db cxt user chatId <*> getDirectChatItem db user chatId itemId
      deletions <- deleteDirectCIs user ct [ci]
      toView $ CEvtChatItemsDeleted user deletions True True
    CTGroup -> do
      (gInfo, ci) <- withStore $ \db -> (,) <$> getGroupInfo db cxt user chatId <*> getGroupChatItem db user chatId itemId
      deletedTs <- liftIO getCurrentTime
      chatScopeInfo <- mapM (getChatScopeInfo cxt user) scope
      deletions <- deleteGroupCIs user gInfo chatScopeInfo [ci] Nothing deletedTs
      toView $ CEvtChatItemsDeleted user deletions True True
    _ -> eToView $ ChatError $ CEInternalError "bad deleteTimedItem cType"

startUpdatedTimedItemThread :: User -> ChatRef -> ChatItem c d -> ChatItem c d -> CM ()
startUpdatedTimedItemThread user chatRef ci ci' =
  case (chatItemTimed ci >>= timedDeleteAt', chatItemTimed ci' >>= timedDeleteAt') of
    (Nothing, Just deleteAt') ->
      startProximateTimedItemThread user (chatRef, chatItemId' ci') deleteAt'
    _ -> pure ()

metaBrokerTs :: MsgMeta -> UTCTime
metaBrokerTs MsgMeta {broker = (_, brokerTs)} = brokerTs

createContactPQSndItem :: User -> Contact -> Connection -> PQEncryption -> CM (Contact, Connection)
createContactPQSndItem user ct conn@Connection {pqSndEnabled} pqSndEnabled' =
  flip catchAllErrors (const $ pure (ct, conn)) $ case (pqSndEnabled, pqSndEnabled') of
    (Just b, b') | b' /= b -> createPQItem $ CISndConnEvent (SCEPqEnabled pqSndEnabled')
    (Nothing, PQEncOn) -> createPQItem $ CISndDirectE2EEInfo (e2eInfoEncrypted $ Just pqSndEnabled')
    _ -> pure (ct, conn)
  where
    createPQItem ciContent = do
      let conn' = conn {pqSndEnabled = Just pqSndEnabled'} :: Connection
          ct' = ct {activeConn = Just conn'} :: Contact
      when (contactPQEnabled ct /= contactPQEnabled ct') $ do
        createInternalChatItem user (CDDirectSnd ct') ciContent Nothing
        toView $ CEvtContactPQEnabled user ct' pqSndEnabled'
      pure (ct', conn')

updateContactPQRcv :: User -> Contact -> Connection -> PQEncryption -> CM (Contact, Connection)
updateContactPQRcv user ct conn@Connection {connId, pqRcvEnabled} pqRcvEnabled' =
  flip catchAllErrors (const $ pure (ct, conn)) $ case (pqRcvEnabled, pqRcvEnabled') of
    (Just b, b') | b' /= b -> updatePQ $ CIRcvConnEvent (RCEPqEnabled pqRcvEnabled')
    (Nothing, PQEncOn) -> updatePQ $ CIRcvDirectE2EEInfo (e2eInfoEncrypted $ Just pqRcvEnabled')
    _ -> pure (ct, conn)
  where
    updatePQ ciContent = do
      withStore' $ \db -> updateConnPQRcvEnabled db connId pqRcvEnabled'
      let conn' = conn {pqRcvEnabled = Just pqRcvEnabled'} :: Connection
          ct' = ct {activeConn = Just conn'} :: Contact
      when (contactPQEnabled ct /= contactPQEnabled ct') $ do
        createInternalChatItem user (CDDirectRcv ct') ciContent Nothing
        toView $ CEvtContactPQEnabled user ct' pqRcvEnabled'
      pure (ct', conn')

updatePeerChatVRange :: Connection -> VersionRangeChat -> CM Connection
updatePeerChatVRange conn@Connection {connId, connChatVersion = v, peerChatVRange, connType, pqSupport, pqEncryption} msgVRange = do
  v' <- lift $ upgradedConnVersion v msgVRange
  conn' <-
    if msgVRange /= peerChatVRange || v' /= v
      then do
        withStore' $ \db -> setPeerChatVRange db connId v' msgVRange
        pure conn {connChatVersion = v', peerChatVRange = msgVRange}
      else pure conn
  -- TODO v6.0 remove/review: for contacts only version upgrade should trigger enabling PQ support/encryption
  if connType == ConnContact && v' >= pqEncryptionCompressionVersion && (pqSupport /= PQSupportOn || pqEncryption /= PQEncOn)
    then do
      withStore' $ \db -> updateConnSupportPQ db connId PQSupportOn PQEncOn
      pure conn' {pqSupport = PQSupportOn, pqEncryption = PQEncOn}
    else pure conn'

updateMemberChatVRange :: GroupMember -> Connection -> VersionRangeChat -> CM (GroupMember, Connection)
updateMemberChatVRange mem@GroupMember {groupMemberId, memberChatVRange} conn@Connection {connId, connChatVersion = v, peerChatVRange} msgVRange = do
  v' <- lift $ upgradedConnVersion v msgVRange
  if msgVRange /= peerChatVRange || v' /= v || msgVRange /= memberChatVRange
    then do
      withStore' $ \db -> do
        setPeerChatVRange db connId v' msgVRange
        setMemberChatVRange db groupMemberId msgVRange
      let conn' = conn {connChatVersion = v', peerChatVRange = msgVRange}
      pure (mem {memberChatVRange = msgVRange, activeConn = Just conn'}, conn')
    else pure (mem, conn)

upgradedConnVersion :: VersionChat -> VersionRangeChat -> CM' VersionChat
upgradedConnVersion v peerVR = do
  vr <- chatVersionRange'
  -- don't allow reducing agreed connection version
  pure $ maybe v (\(Compatible v') -> max v v') $ vr `compatibleVersion` peerVR

parseFileDescription :: FilePartyI p => Text -> CM (ValidFileDescription p)
parseFileDescription =
  liftEither . first (ChatError . CEInvalidFileDescription) . (strDecode . encodeUtf8)

-- | Unique XFTP servers hosting the file's chunks, parsed from a stored file description.
fileDescrServers :: ValidFileDescription p -> [XFTPServer]
fileDescrServers (FD.ValidFileDescription FD.FileDescription {chunks}) =
  S.toList $ S.fromList $ concatMap (\FD.FileChunk {replicas} -> map (\FD.FileChunkReplica {server} -> server) replicas) chunks

-- | XFTP servers the file's data chunks were uploaded to (sender's servers for sent items,
-- the same servers via the recipient description for received items).
-- Returns [] for non-XFTP/inline files or when no description is available; never fails the caller.
getChatItemFileServers :: User -> SMsgDirection d -> ChatItem c d -> CM [XFTPServer]
getChatItemFileServers user dir ci = case ci of
  ChatItem {file = Just CIFile {fileId, fileProtocol = FPXFTP}} ->
    itemFileServers fileId `catchAllErrors` \_ -> pure []
  _ -> pure []
  where
    itemFileServers fileId = case dir of
      SMDSnd -> do
        sfd_ <- withStore' $ \db -> getSndFTPrivateSndDescr db user fileId
        case sfd_ of
          Just sfdText -> fileDescrServers <$> (parseFileDescription sfdText :: CM (ValidFileDescription 'FSender))
          Nothing -> pure []
      SMDRcv -> do
        RcvFileDescr {fileDescrText} <- withStore $ \db -> getRcvFileDescrByRcvFileId db fileId
        fileDescrServers <$> (parseFileDescription fileDescrText :: CM (ValidFileDescription 'FRecipient))

sendDirectFileInline :: User -> Contact -> FileTransferMeta -> SharedMsgId -> CM ()
sendDirectFileInline user ct ft sharedMsgId = do
  msgDeliveryId <- sendFileInline_ ft sharedMsgId $ sendDirectContactMessage user ct
  withStore $ \db -> updateSndDirectFTDelivery db ct ft msgDeliveryId

sendMemberFileInline :: GroupMember -> Connection -> FileTransferMeta -> SharedMsgId -> CM ()
sendMemberFileInline m@GroupMember {groupId} conn ft sharedMsgId = do
  msgDeliveryId <- sendFileInline_ ft sharedMsgId $ \msg -> do
    (sndMsg, msgDeliveryId, _) <- sendDirectMemberMessage conn msg groupId
    pure (sndMsg, msgDeliveryId)
  withStore' $ \db -> updateSndGroupFTDelivery db m conn ft msgDeliveryId

sendFileInline_ :: FileTransferMeta -> SharedMsgId -> (ChatMsgEvent 'Binary -> CM (SndMessage, Int64)) -> CM Int64
sendFileInline_ FileTransferMeta {filePath, chunkSize} sharedMsgId sendMsg =
  sendChunks 1 =<< liftIO . B.readFile =<< lift (toFSFilePath filePath)
  where
    sendChunks chunkNo bytes = do
      let (chunk, rest) = B.splitAt chSize bytes
      (_, msgDeliveryId) <- sendMsg $ BFileChunk sharedMsgId $ FileChunk chunkNo chunk
      if B.null rest
        then pure msgDeliveryId
        else sendChunks (chunkNo + 1) rest
    chSize = fromIntegral chunkSize

parseChatMessage :: Connection -> ByteString -> CM (ChatMessage 'Json)
parseChatMessage conn s = snd <$> parseChatMessage' conn s
{-# INLINE parseChatMessage #-}

parseChatMessage' :: Connection -> ByteString -> CM (Maybe SignedMsg, ChatMessage 'Json)
parseChatMessage' conn s =
  case parseChatMessages s of
    [msg] -> liftEither . first (ChatError . errType) $ (\(APMsg _ (ParsedMsg _ sm m)) -> (sm,) <$> checkEncoding m) =<< msg
    _ -> throwChatError $ CEException "parseChatMessage: single message is expected"
  where
    errType = CEInvalidChatMessage conn Nothing (safeDecodeUtf8 s)

getChatScopeInfo :: StoreCxt -> User -> GroupChatScope -> CM GroupChatScopeInfo
getChatScopeInfo cxt user = \case
  GCSMemberSupport Nothing -> pure $ GCSIMemberSupport Nothing
  GCSMemberSupport (Just gmId) -> do
    supportMem <- withFastStore $ \db -> getGroupMemberById db cxt user gmId
    pure $ GCSIMemberSupport (Just supportMem)

getGroupRecipients :: StoreCxt -> User -> GroupInfo -> Maybe GroupChatScopeInfo -> VersionChat -> CM [GroupMember]
getGroupRecipients cxt user gInfo@GroupInfo {membership} scopeInfo modsCompatVersion
  | useRelays' gInfo && not (isRelay membership) = do
      unless (memberCurrent membership && memberActive membership) $ throwChatError $ CECommandError "not current member"
      withFastStore' $ \db -> getGroupRelayMembers db cxt user gInfo
  | otherwise = case scopeInfo of
      Nothing -> do
        unless (memberCurrent membership && memberActive membership) $ throwChatError $ CECommandError "not current member"
        ms <- withFastStore' $ \db -> getGroupMembers db cxt user gInfo
        pure $ filter memberCurrent ms
      Just (GCSIMemberSupport Nothing) -> do
        modMs <- withFastStore' $ \db -> getGroupModerators db cxt user gInfo
        let rcpModMs' = filter (\m -> compatible m && memberCurrent m) modMs
        when (null rcpModMs') $ throwChatError $ CECommandError "no admins support this message"
        pure rcpModMs'
      Just (GCSIMemberSupport (Just supportMem)) -> do
        unless (memberCurrent membership && memberActive membership) $ throwChatError $ CECommandError "not current member"
        unless (memberCurrentOrPending supportMem) $ throwChatError $ CECommandError "support member not current or pending"
        if memberStatus supportMem == GSMemPendingApproval
          then pure [supportMem]
          else do
            modMs <- withFastStore' $ \db -> getGroupModerators db cxt user gInfo
            let rcpModMs' = filter (\m -> compatible m && memberCurrent m) modMs
            pure $ [supportMem] <> rcpModMs'
  where
    compatible GroupMember {activeConn, memberChatVRange} =
      maxVersion (maybe memberChatVRange peerChatVRange activeConn) >= modsCompatVersion

mkLocalGroupChatScope :: GroupInfo -> CM (GroupInfo, Maybe GroupChatScopeInfo)
mkLocalGroupChatScope gInfo@GroupInfo {membership}
  | memberPending membership = do
      (gInfo', scopeInfo) <- mkGroupSupportChatInfo gInfo
      pure (gInfo', Just scopeInfo)
  | otherwise =
      pure (gInfo, Nothing)

mkGroupChatScope :: GroupInfo -> GroupMember -> CM (GroupInfo, GroupMember, Maybe GroupChatScopeInfo)
mkGroupChatScope gInfo@GroupInfo {membership} m
  | memberPending membership = do
      (gInfo', scopeInfo) <- mkGroupSupportChatInfo gInfo
      pure (gInfo', m, Just scopeInfo)
  | memberPending m = do
      (m', scopeInfo) <- mkMemberSupportChatInfo m
      pure (gInfo, m', Just scopeInfo)
  | otherwise =
      pure (gInfo, m, Nothing)

mkGetMessageChatScope :: StoreCxt -> User -> GroupInfo -> GroupMember -> MsgContent -> Maybe MsgScope -> CM (GroupInfo, GroupMember, Maybe GroupChatScopeInfo)
mkGetMessageChatScope cxt user gInfo@GroupInfo {membership} m mc msgScope_ =
  mkGroupChatScope gInfo m >>= \case
    groupScope@(_gInfo', _m', Just _scopeInfo) -> pure groupScope
    (_, _, Nothing)
      | isReport mc -> do
          -- TODO [knocking] return patched _m'?
          (_m', scopeInfo) <- mkMemberSupportChatInfo m -- only support scope member can send a report (m is sender)
          pure (gInfo, m, Just scopeInfo)
      | otherwise -> case msgScope_ of
          Nothing -> pure (gInfo, m, Nothing)
          Just (MSMember mId)
            | sameMemberId mId membership -> do
                (gInfo', scopeInfo) <- mkGroupSupportChatInfo gInfo
                pure (gInfo', m, Just scopeInfo)
            | otherwise -> do
                referredMember <- withStore $ \db -> getGroupMemberByMemberId db cxt user gInfo mId
                -- TODO [knocking] return patched _referredMember'?
                (_referredMember', scopeInfo) <- mkMemberSupportChatInfo referredMember
                pure (gInfo, m, Just scopeInfo)

mkGroupSupportChatInfo :: GroupInfo -> CM (GroupInfo, GroupChatScopeInfo)
mkGroupSupportChatInfo gInfo@GroupInfo {membership} =
  case supportChat membership of
    Nothing -> do
      chatTs <- liftIO getCurrentTime
      withStore' $ \db -> setSupportChatTs db (groupMemberId' membership) chatTs
      let gInfo' = gInfo {membership = membership {supportChat = Just $ GroupSupportChat chatTs 0 0 0 Nothing}}
          scopeInfo = GCSIMemberSupport {groupMember_ = Nothing}
      pure (gInfo', scopeInfo)
    Just _supportChat ->
      let scopeInfo = GCSIMemberSupport {groupMember_ = Nothing}
       in pure (gInfo, scopeInfo)

mkMemberSupportChatInfo :: GroupMember -> CM (GroupMember, GroupChatScopeInfo)
mkMemberSupportChatInfo m@GroupMember {groupMemberId, supportChat} =
  case supportChat of
    Nothing -> do
      chatTs <- liftIO getCurrentTime
      withStore' $ \db -> setSupportChatTs db groupMemberId chatTs
      let m' = m {supportChat = Just $ GroupSupportChat chatTs 0 0 0 Nothing}
          scopeInfo = GCSIMemberSupport {groupMember_ = Just m'}
      pure (m', scopeInfo)
    Just _supportChat ->
      let scopeInfo = GCSIMemberSupport {groupMember_ = Just m}
       in pure (m, scopeInfo)

appendFileChunk :: RcvFileTransfer -> Integer -> ByteString -> Bool -> CM ()
appendFileChunk ft@RcvFileTransfer {fileId, fileStatus, cryptoArgs, fileInvitation = FileInvitation {fileName}} chunkNo chunk final =
  case fileStatus of
    RFSConnected filePath -> append_ filePath
    -- sometimes update of file transfer status to FSConnected
    -- doesn't complete in time before MSG with first file chunk
    RFSAccepted filePath -> append_ filePath
    RFSCancelled _ -> pure ()
    _ -> throwChatError $ CEFileInternal "receiving file transfer not in progress"
  where
    append_ :: FilePath -> CM ()
    append_ filePath = do
      fsFilePath <- lift $ toFSFilePath filePath
      h <- getFileHandle fileId fsFilePath rcvFiles AppendMode
      liftIO (B.hPut h chunk >> hFlush h) `catchThrow` (fileErr . show)
      withStore' $ \db -> updatedRcvFileChunkStored db ft chunkNo
      when final $ do
        lift $ closeFileHandle fileId rcvFiles
        forM_ cryptoArgs $ \cfArgs -> do
          tmpFile <- lift getChatTempDirectory >>= liftIO . (`uniqueCombine` fileName)
          tryAllErrors (liftError encryptErr $ encryptFile fsFilePath tmpFile cfArgs) >>= \case
            Right () -> do
              removeFile fsFilePath `catchAllErrors` \_ -> pure ()
              renameFile tmpFile fsFilePath
            Left e -> do
              eToView e
              removeFile tmpFile `catchAllErrors` \_ -> pure ()
              withStore' (`removeFileCryptoArgs` fileId)
      where
        encryptErr e = fileErr $ e <> ", received file not encrypted"
        fileErr = ChatError . CEFileWrite filePath

getFileHandle :: Int64 -> FilePath -> (ChatController -> TVar (Map Int64 Handle)) -> IOMode -> CM Handle
getFileHandle fileId filePath files ioMode = do
  fs <- asks files
  h_ <- M.lookup fileId <$> readTVarIO fs
  maybe (newHandle fs) pure h_
  where
    newHandle fs = do
      h <- openFile filePath ioMode `catchThrow` (ChatError . CEFileInternal . show)
      atomically . modifyTVar fs $ M.insert fileId h
      pure h

isFileActive :: Int64 -> (ChatController -> TVar (Map Int64 Handle)) -> CM Bool
isFileActive fileId files = do
  fs <- asks files
  isJust . M.lookup fileId <$> readTVarIO fs

cancelRcvFileTransfer :: User -> RcvFileTransfer -> CM ()
cancelRcvFileTransfer user ft@RcvFileTransfer {fileId, xftpRcvFile} =
  cancel' `catchAllErrors` \e -> eToView e
  where
    cancel' = do
      lift $ closeFileHandle fileId rcvFiles
      withStore' $ \db -> do
        updateFileCancelled db user fileId CIFSRcvCancelled
        updateRcvFileStatus db fileId FSCancelled
        deleteRcvFileChunks db ft
      case xftpRcvFile of
        Just XFTPRcvFile {agentRcvFileId = Just (AgentRcvFileId aFileId), agentRcvFileDeleted} ->
          unless agentRcvFileDeleted $ agentXFTPDeleteRcvFile aFileId fileId
        _ -> pure ()

cancelSndFile :: User -> FileTransferMeta -> [SndFileTransfer] -> Bool -> CM ()
cancelSndFile user FileTransferMeta {fileId, xftpSndFile} fts sendCancel = do
  withStore' (\db -> updateFileCancelled db user fileId CIFSSndCancelled)
    `catchAllErrors` eToView
  case xftpSndFile of
    Nothing ->
      forM_ fts (\ft -> cancelSndFileTransfer user ft sendCancel)
    Just xsf -> do
      forM_ fts (\ft -> cancelSndFileTransfer user ft False)
      lift (agentXFTPDeleteSndFileRemote user xsf fileId) `catchAllErrors` eToView

cancelSndFileTransfer :: User -> SndFileTransfer -> Bool -> CM ()
cancelSndFileTransfer user@User {userId} ft@SndFileTransfer {fileId, connId, fileStatus, fileInline} sendCancel =
  unless (fileStatus == FSCancelled || fileStatus == FSComplete) $
    cancel' `catchAllErrors` \e -> eToView e
  where
    cancel' = do
      withStore' $ \db -> updateSndFileStatus db ft FSCancelled
      when sendCancel $ case fileInline of
        Just _ -> do
          cxt <- chatStoreCxt
          (sharedMsgId, conn) <- withStore $ \db -> (,) <$> getSharedMsgIdByFileId db userId fileId <*> getConnectionById db cxt user connId
          void $ sendDirectMessage_ conn (BFileChunk sharedMsgId FileChunkCancel) (ConnectionId connId)
        _ -> throwChatError $ CEException "cancelSndFileTransfer: cancelling file via a separate connection is deprecated"

closeFileHandle :: Int64 -> (ChatController -> TVar (Map Int64 Handle)) -> CM' ()
closeFileHandle fileId files = do
  fs <- asks files
  h_ <- atomically . stateTVar fs $ \m -> (M.lookup fileId m, M.delete fileId m)
  liftIO $ mapM_ hClose h_ `catchAll_` pure ()

-- The roster file has no chat item, so chat-item file enumeration misses it; clean it up by group.
cleanupGroupRosterFile :: User -> GroupInfo -> CM ()
cleanupGroupRosterFile User {userId} GroupInfo {groupId} = do
  infos <- withStore' $ \db -> getGroupRosterFileInfo db userId groupId
  forM_ infos $ \(fileId, filePath_) -> do
    lift $ closeFileHandle fileId rcvFiles
    forM_ filePath_ removeFsFile
  withStore' $ \db -> do
    deleteGroupRosterFile db userId groupId
    deleteGroupRosterTransfers db groupId

-- Supersede/cancel one source relay's in-flight roster transfer: remove its on-disk file + cached
-- handle first (the cascade only does rows), then the files + transfer rows.
cleanupRosterTransfer :: GroupInfo -> GroupMemberId -> CM ()
cleanupRosterTransfer gInfo fromMemberId =
  withStore' (\db -> getRosterTransferId db gInfo fromMemberId) >>= mapM_ cleanupRosterTransferById

cleanupRosterTransferById :: Int64 -> CM ()
cleanupRosterTransferById transferId = do
  file_ <- withStore' $ \db -> getRosterTransferFile db transferId
  forM_ file_ $ \(fileId, filePath_) -> do
    lift $ closeFileHandle fileId rcvFiles
    forM_ filePath_ removeFsFile
  withStore' $ \db -> do
    deleteRosterTransferFile db transferId
    deleteRosterTransfer db transferId

-- MUST evict the cached AppendMode handle before deleting chunks, else re-driven bytes append
-- after the stale prefix and corrupt the blob.
resetRosterPartialChunks :: RcvFileTransfer -> CM ()
resetRosterPartialChunks ft@RcvFileTransfer {fileId, fileStatus} = do
  lift $ closeFileHandle fileId rcvFiles
  forM_ (rcvFilePath fileStatus) removeFsFile
  withStore' $ \db -> deleteRcvFileChunks db ft
  where
    rcvFilePath = \case
      RFSAccepted p -> Just p
      RFSConnected p -> Just p
      _ -> Nothing

removeFsFile :: FilePath -> CM ()
removeFsFile fp = do
  p <- lift $ toFSFilePath fp
  removeFile p `catchAllErrors` \_ -> pure ()

deleteMembersConnections :: User -> [GroupMember] -> CM ()
deleteMembersConnections user members = deleteMembersConnections' user members False

deleteMembersConnections' :: User -> [GroupMember] -> Bool -> CM ()
deleteMembersConnections' user members waitDelivery = do
  let memberConns = mapMaybe (\GroupMember {activeConn} -> activeConn) members
  deleteAgentConnectionsAsync' (map aConnId memberConns) waitDelivery
  lift . void . withStoreBatch' $ \db -> map (\Connection {connId} -> deleteConnectionRecord db user connId) memberConns

deleteMemberConnection :: GroupMember -> CM ()
deleteMemberConnection mem = deleteMemberConnection' mem False

deleteMemberConnection' :: GroupMember -> Bool -> CM ()
deleteMemberConnection' GroupMember {activeConn} waitDelivery = do
  forM_ activeConn $ \conn -> do
    deleteAgentConnectionAsync' (aConnId conn) waitDelivery
    withStore' $ \db -> updateConnectionStatus db conn ConnDeleted

deleteOrUpdateMemberRecord :: User -> GroupInfo -> GroupMember -> CM GroupInfo
deleteOrUpdateMemberRecord user gInfo m =
  withStore' $ \db -> deleteOrUpdateMemberRecordIO db user gInfo m

deleteOrUpdateMemberRecordIO :: DB.Connection -> User -> GroupInfo -> GroupMember -> IO GroupInfo
deleteOrUpdateMemberRecordIO db user@User {userId} gInfo m = do
  (gInfo', m') <- deleteSupportChatIfExists db user gInfo m
  if isRelay m'
    then deleteGroupMember db user m'
    else
      checkGroupMemberHasItems db user m' >>= \case
        Just _ -> updateGroupMemberStatus db userId m' GSMemRemoved
        Nothing
          | useRelays' gInfo -> updateGroupMemberRemovedAt db user m'
          | otherwise -> deleteGroupMember db user m'
  pure gInfo'

-- Unlike deleteOrUpdateMemberRecord, skips checkGroupMemberHasItems.
fullyDeleteMemberRecord :: User -> GroupInfo -> GroupMember -> CM GroupInfo
fullyDeleteMemberRecord user gInfo m =
  withStore' $ \db -> fullyDeleteMemberRecordIO db user gInfo m

fullyDeleteMemberRecordIO :: DB.Connection -> User -> GroupInfo -> GroupMember -> IO GroupInfo
fullyDeleteMemberRecordIO db user gInfo m = do
  (gInfo', m') <- deleteSupportChatIfExists db user gInfo m
  if useRelays' gInfo && not (isRelay m')
    then updateGroupMemberRemovedAt db user m'
    else deleteGroupMember db user m'
  pure gInfo'

updateMemberRecordDeleted :: User -> GroupInfo -> GroupMember -> GroupMemberStatus -> CM GroupInfo
updateMemberRecordDeleted user@User {userId} gInfo m newStatus =
  withStore' $ \db -> do
    (gInfo', m') <- deleteSupportChatIfExists db user gInfo m
    updateGroupMemberStatus db userId m' newStatus
    deactivateRelay_ db m
    pure gInfo'

deactivateRelay_ :: DB.Connection -> GroupMember -> IO ()
deactivateRelay_ db m =
  when (isRelay m) $ do
    relay_ <- runExceptT $ getGroupRelayByGMId db (groupMemberId' m)
    forM_ relay_ $ \relay -> void $ updateRelayStatus db relay RSInactive

deleteSupportChatIfExists :: DB.Connection -> User -> GroupInfo -> GroupMember -> IO (GroupInfo, GroupMember)
deleteSupportChatIfExists db user gInfo m = do
  gInfo' <-
    if gmRequiresAttention m
      then decreaseGroupMembersRequireAttention db user gInfo
      else pure gInfo
  m' <-
    if isJust (supportChat m)
      then deleteGroupMemberSupportChat db m
      else pure m
  pure (gInfo', m')

sendDirectContactMessages :: MsgEncodingI e => User -> Contact -> NonEmpty (ChatMsgEvent e) -> CM [Either ChatError SndMessage]
sendDirectContactMessages user ct events = do
  Connection {connChatVersion = v} <- liftEither $ contactSendConn_ ct
  if v >= batchSend2Version
    then sendDirectContactMessages' user ct events
    else forM (L.toList events) $ \evt ->
      (Right . fst <$> sendDirectContactMessage user ct evt) `catchAllErrors` \e -> pure (Left e)

sendDirectContactMessages' :: MsgEncodingI e => User -> Contact -> NonEmpty (ChatMsgEvent e) -> CM [Either ChatError SndMessage]
sendDirectContactMessages' user ct events = do
  conn@Connection {connId} <- liftEither $ contactSendConn_ ct
  let idsEvts = L.map (ConnectionId connId,Nothing,) events
      msgFlags = MsgFlags {notification = any (hasNotification . toCMEventTag) events}
  sndMsgs_ <- lift $ createSndMessages idsEvts
  (sndMsgs', pqEnc_) <- batchSendConnMessagesB BMJson user conn msgFlags sndMsgs_
  forM_ pqEnc_ $ \pqEnc' -> void $ createContactPQSndItem user ct conn pqEnc'
  pure sndMsgs'

-- present the user's own badge on an outgoing profile: a fresh, single-use proof from the stored credential.
-- the send's incognito profile (when set) suppresses it - an incognito identity must never carry the badge.
-- a long-expired badge is not presented at all (receivers would hide it anyway).
presentUserBadge :: User -> Maybe i -> Profile -> CM Profile
presentUserBadge User {profile = LocalProfile {localBadge}} incognitoProfile p = case (incognitoProfile, localBadge) of
  (Nothing, Just (OwnBadge cred@(BadgeCredential keyIdx _ _ _) st)) | st == BSActive || st == BSExpired -> do
    keys <- asks $ badgePublicKeys . config
    case M.lookup keyIdx keys of
      Nothing -> p <$ logError "presentUserBadge: badge key index not in config"
      Just key -> do
        nonce <- drgRandomBytes 16
        -- TODO [SECURITY/DEPRECATED]: PHTest is a test presentation header not bound to any
        -- application context. Must be replaced with a context-bound BadgePresHeader before v7.
        -- See Badges.hs badgePresHeaderAccepted for details.
        liftIO (badgeProof key cred (PHTest nonce)) >>= \case
          Right proof -> pure p {badge = Just proof}
          Left e -> p <$ logError ("presentUserBadge: proof generation failed: " <> T.pack e)
  _ -> pure p


-- receiving side of contact/invitation link data: verify the badge proof from the link profile
-- and set the crypto-free display badge for the UI (the raw proof stays in profile for APIPrepareContact)
linkDataBadge :: ContactShortLinkData -> CM ContactShortLinkData
linkDataBadge cld@ContactShortLinkData {profile = Profile {badge}} = case badge of
  Nothing -> pure cld
  Just b@(BadgeProof _ _ _ info) -> do
    keys <- asks $ badgePublicKeys . config
    verified <- liftIO $ verifyBadge keys b
    now <- liftIO getCurrentTime
    pure (cld :: ContactShortLinkData) {localBadge = Just $ ShownBadge info (mkBadgeStatus now verified info)}

sendDirectContactMessage :: MsgEncodingI e => User -> Contact -> ChatMsgEvent e -> CM (SndMessage, Int64)
sendDirectContactMessage user ct chatMsgEvent = do
  conn@Connection {connId} <- liftEither $ contactSendConn_ ct
  r <- sendDirectMessage_ conn chatMsgEvent (ConnectionId connId)
  let (sndMessage, msgDeliveryId, pqEnc') = r
  void $ createContactPQSndItem user ct conn pqEnc'
  pure (sndMessage, msgDeliveryId)

contactSendConn_ :: Contact -> Either ChatError Connection
contactSendConn_ ct@Contact {activeConn} = case activeConn of
  Nothing -> err $ CEContactNotReady ct
  Just conn
    | not (connReady conn) -> err $ CEContactNotReady ct
    | not (contactActive ct) -> err $ CEContactNotActive ct
    | connDisabled conn -> err $ CEContactDisabled ct
    | otherwise -> Right conn
  where
    err = Left . ChatError

-- unlike sendGroupMemberMessage, this function will not store message as pending
-- TODO v5.8 we could remove pending messages once all clients support forwarding
sendDirectMemberMessage :: MsgEncodingI e => Connection -> ChatMsgEvent e -> GroupId -> CM (SndMessage, Int64, PQEncryption)
sendDirectMemberMessage conn chatMsgEvent groupId = sendDirectMessage_ conn chatMsgEvent (GroupId groupId)

sendDirectMessage_ :: MsgEncodingI e => Connection -> ChatMsgEvent e -> ConnOrGroupId -> CM (SndMessage, Int64, PQEncryption)
sendDirectMessage_ conn chatMsgEvent connOrGroupId = do
  when (connDisabled conn) $ throwChatError (CEConnectionDisabled conn)
  msg@SndMessage {msgId, msgBody} <- createSndMessage chatMsgEvent connOrGroupId
  -- TODO move compressed body to SndMessage and compress in createSndMessage
  (msgDeliveryId, pqEnc') <- deliverMessage conn (toCMEventTag chatMsgEvent) msgBody msgId
  pure (msg, msgDeliveryId, pqEnc')

createSndMessage :: MsgEncodingI e => ChatMsgEvent e -> ConnOrGroupId -> CM SndMessage
createSndMessage chatMsgEvent connOrGroupId =
  liftEither . runIdentity =<< lift (createSndMessages $ Identity (connOrGroupId, Nothing, chatMsgEvent))

createSndMessages :: forall e t. (MsgEncodingI e, Traversable t) => t (ConnOrGroupId, Maybe MsgSigning, ChatMsgEvent e) -> CM' (t (Either ChatError SndMessage))
createSndMessages idsEvents = do
  g <- asks random
  vr <- chatVersionRange'
  withStoreBatch $ \db -> fmap (createMsg db g vr) idsEvents
  where
    createMsg :: DB.Connection -> TVar ChaChaDRG -> VersionRangeChat -> (ConnOrGroupId, Maybe MsgSigning, ChatMsgEvent e) -> IO (Either ChatError SndMessage)
    createMsg db g vr (connOrGroupId, msgSigning_, evnt) = runExceptT $ do
      withExceptT ChatErrorStore $ createNewSndMessage db g connOrGroupId evnt msgSigning_ encodeMessage
      where
        encodeMessage sharedMsgId =
          encodeChatMessage maxEncodedMsgLength ChatMessage {chatVRange = vr, msgId = Just sharedMsgId, chatMsgEvent = evnt}

groupMsgSigning :: Bool -> GroupInfo -> ChatMsgEvent e -> Maybe MsgSigning
groupMsgSigning sign gInfo@GroupInfo {membership = GroupMember {memberId}, groupKeys = Just GroupKeys {publicGroupId, memberPrivKey}} evt
  | useRelays' gInfo && shouldSign =
      Just $ MsgSigning CBGroup (smpEncode (publicGroupId, memberId)) KRMember memberPrivKey
  where
    tag = toCMEventTag evt
    shouldSign = requiresSignature tag || (sign && signableContent tag)
groupMsgSigning _ _ _ = Nothing

sendGroupMemberMessages :: forall e. MsgEncodingI e => User -> GroupInfo -> Connection -> NonEmpty (ChatMsgEvent e) -> CM ()
sendGroupMemberMessages user gInfo@GroupInfo {groupId} conn events = do
  when (connDisabled conn) $ throwChatError (CEConnectionDisabled conn)
  let idsEvts = L.map (\evt -> (GroupId groupId, groupMsgSigning False gInfo evt, evt)) events
      mode = if useRelays' gInfo then BMBinary else BMJson
  (errs, msgs) <- lift $ partitionEithers . L.toList <$> createSndMessages idsEvts
  unless (null errs) $ toView $ CEvtChatErrors errs
  forM_ (L.nonEmpty msgs) $ \msgs' ->
    batchSendConnMessages mode user conn MsgFlags {notification = True} msgs'

batchSendConnMessages :: BatchMode -> User -> Connection -> MsgFlags -> NonEmpty SndMessage -> CM ([Either ChatError SndMessage], Maybe PQEncryption)
batchSendConnMessages mode user conn msgFlags msgs =
  batchSendConnMessagesB mode user conn msgFlags $ L.map Right msgs

batchSendConnMessagesB :: BatchMode -> User -> Connection -> MsgFlags -> NonEmpty (Either ChatError SndMessage) -> CM ([Either ChatError SndMessage], Maybe PQEncryption)
batchSendConnMessagesB mode _user conn msgFlags msgs_ = do
  let batched_ = batchSndMessagesJSON mode msgs_
  case L.nonEmpty batched_ of
    Just batched' -> do
      let msgReqs = L.map (fmap msgBatchReq_) batched'
      delivered <- deliverMessagesB msgReqs
      let msgs' = concat $ L.zipWith flattenMsgs batched' delivered
          pqEnc = findLastPQEnc delivered
      when (length msgs' /= length msgs_) $ logError "batchSendConnMessagesB: msgs_ and msgs' length mismatch"
      pure (msgs', pqEnc)
    Nothing -> pure ([], Nothing)
  where
    msgBatchReq_ :: MsgBatch -> ChatMsgReq
    msgBatchReq_ (MsgBatch batchBody sndMsgs) =
      (conn, msgFlags, (vrValue batchBody, map (\SndMessage {msgId} -> msgId) sndMsgs))
    flattenMsgs :: Either ChatError MsgBatch -> Either ChatError ([Int64], PQEncryption) -> [Either ChatError SndMessage]
    flattenMsgs (Right (MsgBatch _ sndMsgs)) (Right _) = map Right sndMsgs
    flattenMsgs (Right (MsgBatch _ sndMsgs)) (Left ce) = replicate (length sndMsgs) (Left ce)
    flattenMsgs (Left ce) _ = [Left ce] -- restore original ChatError
    findLastPQEnc :: NonEmpty (Either ChatError ([Int64], PQEncryption)) -> Maybe PQEncryption
    findLastPQEnc = foldr' (\x acc -> case x of Right (_, pqEnc) -> Just pqEnc; Left _ -> acc) Nothing

batchSndMessagesJSON :: BatchMode -> NonEmpty (Either ChatError SndMessage) -> [Either ChatError MsgBatch]
batchSndMessagesJSON mode = batchMessages mode maxEncodedMsgLength . L.toList

encodeConnInfo :: MsgEncodingI e => ChatMsgEvent e -> CM ByteString
encodeConnInfo chatMsgEvent = do
  cxt <- chatStoreCxt
  encodeConnInfoPQ PQSupportOff (maxVersion (vr cxt)) chatMsgEvent

encodeConnInfoPQ :: MsgEncodingI e => PQSupport -> VersionChat -> ChatMsgEvent e -> CM ByteString
encodeConnInfoPQ pqSup v chatMsgEvent = do
  cxt <- chatStoreCxt
  let info = ChatMessage {chatVRange = vr cxt, msgId = Nothing, chatMsgEvent}
  case encodeChatMessage maxEncodedInfoLength info of
    ECMEncoded connInfo -> case pqSup of
      PQSupportOn | v >= pqEncryptionCompressionVersion && B.length connInfo > maxCompressedInfoLength -> do
        let connInfo' = compressedBatchMsgBody_ connInfo
        when (B.length connInfo' > maxCompressedInfoLength) $ throwChatError $ CEException "large compressed info"
        pure connInfo'
      _ -> pure connInfo
    ECMLarge -> throwChatError $ CEException "large info"

-- conn-info wrapped as a signed element, so the receiver can verify the signature over the body
encodeSignedConnInfo :: MsgEncodingI e => MsgSigning -> ChatMsgEvent e -> CM ByteString
encodeSignedConnInfo signing chatMsgEvent = do
  vr <- chatVersionRange
  let info = ChatMessage {chatVRange = vr, msgId = Nothing, chatMsgEvent}
  case encodeChatMessage maxEncodedInfoLength info of
    ECMEncoded body -> pure $ encodeBatchElement (Just $ signChatMsgBody signing body) body
    ECMLarge -> throwChatError $ CEException "large signed info"

-- signed XMember for a relay-group join: proves the joiner holds the member key it asserts, and carries
-- viaRelay = the target relay's memberId inside the signed body so a sibling relay can't accept a replay
encodeXMemberConnInfo :: GroupInfo -> MemberId -> Profile -> CM ByteString
encodeXMemberConnInfo GroupInfo {membership = GroupMember {memberId}, groupKeys} relayMemberId profileToSend =
  case groupKeys of
    Just GroupKeys {publicGroupId, memberPrivKey} ->
      let xMemberEvt = XMember profileToSend memberId (MemberKey $ C.publicKey memberPrivKey) (Just relayMemberId)
          signing = MsgSigning CBGroup (smpEncode (publicGroupId, memberId)) KRMember memberPrivKey
       in encodeSignedConnInfo signing xMemberEvt
    Nothing -> throwChatError $ CEInternalError "no group keys for channel membership"

deliverMessage :: Connection -> CMEventTag e -> MsgBody -> MessageId -> CM (Int64, PQEncryption)
deliverMessage conn cmEventTag msgBody msgId = do
  let msgFlags = MsgFlags {notification = hasNotification cmEventTag}
  deliverMessage' conn msgFlags msgBody msgId

deliverMessage' :: Connection -> MsgFlags -> MsgBody -> MessageId -> CM (Int64, PQEncryption)
deliverMessage' conn msgFlags msgBody msgId =
  deliverMessages ((conn, msgFlags, (vrValue msgBody, [msgId])) :| []) >>= \case
    r :| [] -> case r of
      Right ([deliveryId], pqEnc) -> pure (deliveryId, pqEnc)
      Right (deliveryIds, _) -> throwChatError $ CEInternalError $ "deliverMessage: expected 1 delivery id, got " <> show (length deliveryIds)
      Left e -> throwError e
    rs -> throwChatError $ CEInternalError $ "deliverMessage: expected 1 result, got " <> show (length rs)

-- [MessageId] - SndMessage ids inside MsgBatch, or single message id
type ChatMsgReq = (Connection, MsgFlags, (ValueOrRef MsgBody, [MessageId]))

deliverMessages :: NonEmpty ChatMsgReq -> CM (NonEmpty (Either ChatError ([Int64], PQEncryption)))
deliverMessages msgs = deliverMessagesB $ L.map Right msgs

deliverMessagesB :: NonEmpty (Either ChatError ChatMsgReq) -> CM (NonEmpty (Either ChatError ([Int64], PQEncryption)))
deliverMessagesB msgReqs = do
  msgReqs' <- if any connSupportsPQ msgReqs then liftIO compressBodies else pure msgReqs
  sent <- L.zipWith prepareBatch msgReqs' <$> withAgent (`sendMessagesB` snd (mapAccumL toAgent Nothing msgReqs'))
  lift . void $ withStoreBatch' $ \db -> map (updatePQSndEnabled db) (rights . L.toList $ sent)
  lift . withStoreBatch $ \db -> L.map (bindRight $ createDelivery db) sent
  where
    connSupportsPQ = \case
      Right (Connection {pqSupport = PQSupportOn, connChatVersion = v}, _, _) -> v >= pqEncryptionCompressionVersion
      _ -> False
    compressBodies =
      forME msgReqs $ \(conn, msgFlags, (mbr, msgIds)) -> runExceptT $ do
        mbr' <- case mbr of
          VRValue i msgBody | B.length msgBody > maxCompressedMsgLength -> do
            let msgBody' = compressedBatchMsgBody_ msgBody
            when (B.length msgBody' > maxCompressedMsgLength) $ throwError $ ChatError $ CEException "large compressed message"
            pure $ VRValue i msgBody'
          v -> pure v
        pure (conn, msgFlags, (mbr', msgIds))
    toAgent prev = \case
      Right (conn@Connection {connId, pqEncryption}, msgFlags, (mbr, _msgIds)) ->
        let cId = case prev of
              Just prevId | prevId == connId -> ""
              _ -> aConnId conn
         in (Just connId, Right (cId, pqEncryption, msgFlags, mbr))
      Left _ce -> (prev, Left (AP.INTERNAL "ChatError, skip")) -- as long as it is Left, the agent batchers should just step over it
    prepareBatch (Right req) (Right ar) = Right (req, ar)
    prepareBatch (Left ce) _ = Left ce -- restore original ChatError
    prepareBatch _ (Left ae) = Left $ chatErrorAgent ae
    createDelivery :: DB.Connection -> (ChatMsgReq, (AgentMsgId, PQEncryption)) -> IO (Either ChatError ([Int64], PQEncryption))
    createDelivery db ((Connection {connId}, _, (_, msgIds)), (agentMsgId, pqEnc')) = do
      Right . (,pqEnc') <$> mapM (createSndMsgDelivery db (SndMsgDelivery {connId, agentMsgId})) msgIds
    updatePQSndEnabled :: DB.Connection -> (ChatMsgReq, (AgentMsgId, PQEncryption)) -> IO ()
    updatePQSndEnabled db ((Connection {connId, pqSndEnabled}, _, _), (_, pqSndEnabled')) =
      case (pqSndEnabled, pqSndEnabled') of
        (Just b, b') | b' /= b -> updatePQ
        (Nothing, PQEncOn) -> updatePQ
        _ -> pure ()
      where
        updatePQ = updateConnPQSndEnabled db connId pqSndEnabled'

sendGroupMessage :: MsgEncodingI e => User -> GroupInfo -> Maybe GroupChatScope -> [GroupMember] -> Bool -> ChatMsgEvent e -> CM SndMessage
sendGroupMessage user gInfo gcScope members sign chatMsgEvent = do
  sendGroupMessages user gInfo gcScope False members sign (chatMsgEvent :| []) >>= \case
    ((Right msg) :| [], _) -> pure msg
    _ -> throwChatError $ CEInternalError "sendGroupMessage: expected 1 message"

sendGroupMessage' :: MsgEncodingI e => User -> GroupInfo -> [GroupMember] -> ChatMsgEvent e -> CM SndMessage
sendGroupMessage' user gInfo members chatMsgEvent =
  sendGroupMessages_ user gInfo members False (chatMsgEvent :| []) >>= \case
    ((Right msg) :| [], _) -> pure msg
    _ -> throwChatError $ CEInternalError "sendGroupMessage': expected 1 message"

-- The roster change being broadcast, projected onto the current roster members in broadcastRoster. This lets the
-- roster blob be built (and sent) before the change is applied to the owner's own member records, so the owner
-- never demotes/removes a member locally before the change has been propagated to relays.
data RosterDelta
  = RDRoleChanged GroupMemberRole [GroupMember] -- these members now hold this role
  | RDRemoved [GroupMember] -- these members are removed from the group

applyRosterDelta :: RosterDelta -> [GroupMember] -> [GroupMember]
applyRosterDelta delta current = case delta of
  RDRoleChanged role changed -> map (\m -> (m :: GroupMember) {memberRole = role}) changed <> without changed
  RDRemoved removed -> without removed
  where
    without ms = let ids = S.fromList (map groupMemberId' ms) in filter ((`S.notMember` ids) . groupMemberId') current

-- TODO [relays] improvement: publish roster_version in link data so the owner can recover the latest version
-- TODO   after restoring from a stale backup (relays accept only strictly-greater versions)
-- Reserve and persist the next roster version (committed before the events that carry it, so a recipient never
-- advances past a version the owner hasn't recorded), then broadcast the matching blob with the change projected
-- onto the served roster (so it excludes demoted/removed members). Returns the reserved version for the delta
-- that follows. The blob send is best-effort - a failed send heals on the next change or on resume.
broadcastRoster :: User -> GroupInfo -> RosterDelta -> CM VersionRoster
broadcastRoster user gInfo delta = do
  let rosterVer = maybe (VersionRoster 0) (\(VersionRoster n) -> VersionRoster (n + 1)) (rosterVersion gInfo)
  withStore' $ \db -> setGroupRosterVersion db gInfo rosterVer
  sendRosterBlob rosterVer `catchAllErrors` eToView
  pure rosterVer
  where
    sendRosterBlob rosterVer = do
      cxt <- chatStoreCxt
      (relays, rosterMems) <- withStore' $ \db ->
        (,) <$> getGroupRelayMembers db cxt user gInfo <*> getGroupRosterMembers db cxt user gInfo
      forM_ (L.nonEmpty relays) $ \relays' ->
        sendRoster user gInfo (L.toList relays') rosterVer (buildGroupRoster $ applyRosterDelta delta rosterMems)

-- Send the current roster (no version bump) to a newly added relay so it can serve joiners.
sendGroupRosterToRelay :: User -> GroupInfo -> GroupMember -> CM ()
sendGroupRosterToRelay user gInfo relayMember =
  forM_ (rosterVersion gInfo) $ \rosterVer -> do
    cxt <- chatStoreCxt
    rosterMems <- withStore' $ \db -> getGroupRosterMembers db cxt user gInfo
    sendRoster user gInfo [relayMember] rosterVer (buildGroupRoster rosterMems)

-- Row-less send (no files/snd_files rows, so no send-side cleanup); redelivery is the agent's.
sendRoster :: User -> GroupInfo -> [GroupMember] -> VersionRoster -> [RosterMember] -> CM ()
sendRoster user gInfo members rosterVer roster = do
  let blob = encodeRosterBlob roster
      fileInv = InlineFileInvitation {fileSize = fromIntegral (B.length blob), fileDigest = FD.FileDigest $ LC.sha512Hash $ LB.fromStrict blob}
  SndMessage {sharedMsgId} <- sendGroupMessage' user gInfo members (XGrpRoster GroupRoster {version = rosterVer, fileInv})
  sendInlineBlobChunks user gInfo members sharedMsgId blob

-- Send a binary blob as BFileChunks under a shared_msg_id to the given members (chunked by fileChunkSize).
sendInlineBlobChunks :: User -> GroupInfo -> [GroupMember] -> SharedMsgId -> ByteString -> CM ()
sendInlineBlobChunks user gInfo members sharedMsgId blob = do
  chSize <- fromIntegral <$> asks (fileChunkSize . config)
  go chSize 1 blob
  where
    go chSize chunkNo bytes = do
      let (chunk, rest) = B.splitAt chSize bytes
      void $ sendGroupMessage' user gInfo members (BFileChunk sharedMsgId (FileChunk chunkNo chunk))
      unless (B.null rest) $ go chSize (chunkNo + 1) rest

-- Relay advertises its current web preview capability to channel owners.
-- Idempotent: sends only when the configured web domain differs from what was last sent, and only to
-- owners whose recorded chat version supports relayWebCapVersion (older apps can't parse XGrpRelayCap).
sendRelayCapIfNeeded :: User -> GroupInfo -> CM ()
sendRelayCapIfNeeded user gInfo = do
  ChatConfig {webPreviewConfig} <- asks config
  let currentWebDomain = (\WebPreviewConfig {webDomain} -> webDomain) <$> webPreviewConfig
  sentWebDomain <- withStore' (`getRelaySentWebDomain` gInfo)
  when (currentWebDomain /= sentWebDomain) $ do
    cxt <- chatStoreCxt
    owners <- withStore' $ \db -> getGroupOwners db cxt user gInfo
    let capableOwners = filter (\m -> memberCurrent m && m `supportsVersion` relayWebCapVersion) owners
    unless (null capableOwners) $ do
      void $ sendGroupMessage' user gInfo capableOwners (XGrpRelayCap RelayCapabilities {webDomain = currentWebDomain})
      withStore' $ \db -> updateRelaySentWebDomain db gInfo currentWebDomain

sendGroupMessages :: MsgEncodingI e => User -> GroupInfo -> Maybe GroupChatScope -> ShowGroupAsSender -> [GroupMember] -> Bool -> NonEmpty (ChatMsgEvent e) -> CM (NonEmpty (Either ChatError SndMessage), GroupSndResult)
sendGroupMessages user gInfo scope asGroup members sign events = do
  sendGroupProfileUpdate user gInfo scope asGroup members
  sendGroupMessages_ user gInfo members sign events

-- per-item signer variant of sendGroupMessages (used for per-item delete signing); preserves the profile-update prelude
sendGroupSignedMessages :: MsgEncodingI e => User -> GroupInfo -> Maybe GroupChatScope -> ShowGroupAsSender -> [GroupMember] -> NonEmpty (Maybe MsgSigning, ChatMsgEvent e) -> CM (NonEmpty (Either ChatError SndMessage), GroupSndResult)
sendGroupSignedMessages user gInfo scope asGroup members signedEvents = do
  sendGroupProfileUpdate user gInfo scope asGroup members
  sendGroupSignedMessages_ gInfo members signedEvents

sendGroupProfileUpdate :: User -> GroupInfo -> Maybe GroupChatScope -> ShowGroupAsSender -> [GroupMember] -> CM ()
sendGroupProfileUpdate user gInfo scope asGroup members =
  -- TODO [knocking] send current profile to pending member after approval?
  when shouldSendProfileUpdate $
    sendProfileUpdate `catchAllErrors` eToView
  where
    User {profile = p, userMemberProfileUpdatedAt} = user
    GroupInfo {userMemberProfileSentAt} = gInfo
    shouldSendProfileUpdate
      | asGroup = False
      | isJust scope = False -- why not sending profile updates to scopes?
      | incognitoMembership gInfo = False
      | otherwise =
          case (userMemberProfileSentAt, userMemberProfileUpdatedAt) of
            (Just lastSentTs, Just lastUpdateTs) -> lastSentTs < lastUpdateTs
            (Nothing, Just _) -> True
            _ -> False
    sendProfileUpdate = do
      let members' = filter (`supportsVersion` memberProfileUpdateVersion) members
      -- shouldSendProfileUpdate excludes incognito membership, so the badge is presented
      profileUpdate <- presentUserBadge user Nothing $ redactedMemberProfile gInfo (membership gInfo) $ fromLocalProfile p
      void $ sendGroupMessage' user gInfo members' $ XInfo profileUpdate
      currentTs <- liftIO getCurrentTime
      withStore' $ \db -> updateUserMemberProfileSentAt db user gInfo currentTs

data GroupSndResult = GroupSndResult
  { sentTo :: [(GroupMemberId, Either ChatError [MessageId], Either ChatError ([Int64], PQEncryption))],
    pending :: [(GroupMemberId, Either ChatError MessageId, Either ChatError ())],
    forwarded :: [GroupMember]
  }

sendGroupMessages_ :: MsgEncodingI e => User -> GroupInfo -> [GroupMember] -> Bool -> NonEmpty (ChatMsgEvent e) -> CM (NonEmpty (Either ChatError SndMessage), GroupSndResult)
sendGroupMessages_ _user gInfo recipientMembers sign events =
  sendGroupSignedMessages_ gInfo recipientMembers $ L.map (\evt -> (groupMsgSigning sign gInfo evt, evt)) events

sendGroupSignedMessages_ :: MsgEncodingI e => GroupInfo -> [GroupMember] -> NonEmpty (Maybe MsgSigning, ChatMsgEvent e) -> CM (NonEmpty (Either ChatError SndMessage), GroupSndResult)
sendGroupSignedMessages_ gInfo@GroupInfo {groupId} recipientMembers signedEvents = do
  sndMsgs_ <- lift $ createSndMessages idsEvts
  recipientMembers' <- liftIO $ shuffleMembers recipientMembers
  let msgFlags = MsgFlags {notification = any (hasNotification . toCMEventTag) events}
      (toSendSeparate, toSendBatched, toPending, forwarded, _, dups) =
        foldr' (addMember recipientMembers') ([], [], [], [], S.empty, 0 :: Int) recipientMembers'
  when (dups /= 0) $ logError $ "sendGroupMessages_: " <> tshow dups <> " duplicate members"
  -- TODO PQ either somehow ensure that group members connections cannot have pqSupport/pqEncryption or pass Off's here
  -- Deliver to toSend members
  let (sendToMemIds, msgReqs) = prepareMsgReqs msgFlags sndMsgs_ toSendSeparate toSendBatched
  delivered <- maybe (pure []) (fmap L.toList . deliverMessagesB) $ L.nonEmpty msgReqs
  when (length delivered /= length sendToMemIds) $ logError "sendGroupMessages_: sendToMemIds and delivered length mismatch"
  -- Save as pending for toPending members
  let (pendingMemIds, pendingReqs) = preparePending sndMsgs_ toPending
  stored <- lift $ withStoreBatch (\db -> map (bindRight $ createPendingMsg db) pendingReqs)
  when (length stored /= length pendingMemIds) $ logError "sendGroupMessages_: pendingMemIds and stored length mismatch"
  -- Zip for easier access to results
  let sentTo = zipWith3 (\mId mReq r -> (mId, fmap (\(_, _, (_, msgIds)) -> msgIds) mReq, r)) sendToMemIds msgReqs delivered
      pending = zipWith3 (\mId pReq r -> (mId, fmap snd pReq, r)) pendingMemIds pendingReqs stored
  pure (sndMsgs_, GroupSndResult {sentTo, pending, forwarded})
  where
    events = L.map snd signedEvents
    idsEvts = L.map (\(signing, evt) -> (GroupId groupId, signing, evt)) signedEvents
    shuffleMembers :: [GroupMember] -> IO [GroupMember]
    shuffleMembers ms = do
      let (adminMs, otherMs) = partition isAdmin ms
      liftM2 (<>) (shuffle adminMs) (shuffle otherMs)
      where
        isAdmin GroupMember {memberRole} = memberRole >= GRAdmin
    addMember members m acc@(toSendSeparate, toSendBatched, pending, forwarded, !mIds, !dups) =
      case memberSendAction gInfo events members m of
        Just a
          | mId `S.member` mIds -> (toSendSeparate, toSendBatched, pending, forwarded, mIds, dups + 1)
          | otherwise -> case a of
              MSASend conn -> ((m, conn) : toSendSeparate, toSendBatched, pending, forwarded, mIds', dups)
              MSASendBatched conn -> (toSendSeparate, (m, conn) : toSendBatched, pending, forwarded, mIds', dups)
              MSAPending -> (toSendSeparate, toSendBatched, m : pending, forwarded, mIds', dups)
              MSAForwarded -> (toSendSeparate, toSendBatched, pending, m : forwarded, mIds', dups)
        Nothing -> acc
      where
        mId = groupMemberId' m
        mIds' = S.insert mId mIds
    prepareMsgReqs :: MsgFlags -> NonEmpty (Either ChatError SndMessage) -> [(GroupMember, Connection)] -> [(GroupMember, Connection)] -> ([GroupMemberId], [Either ChatError ChatMsgReq])
    prepareMsgReqs msgFlags msgs toSendSeparate toSendBatched = do
      let mode = if useRelays' gInfo then BMBinary else BMJson
          batched_ = batchSndMessagesJSON mode msgs
      case L.nonEmpty batched_ of
        Just batched' -> do
          let lenMsgs = length msgs
              (memsSep, mreqsSep) = foldMembers lenMsgs sndMessageMBR msgs toSendSeparate
              (memsBtch, mreqsBtch) = foldMembers (length batched' + lenMsgs) msgBatchMBR batched' toSendBatched
          (memsSep <> memsBtch, mreqsSep <> mreqsBtch)
        Nothing -> ([], [])
      where
        foldMembers :: forall a. Int -> (Maybe Int -> Int -> a -> (ValueOrRef MsgBody, [MessageId])) -> NonEmpty (Either ChatError a) -> [(GroupMember, Connection)] -> ([GroupMemberId], [Either ChatError ChatMsgReq])
        foldMembers lastRef mkMb mbs mems = snd $ foldr' foldMsgBodies (lastMemIdx_, ([], [])) mems
          where
            lastMemIdx_ = let len = length mems in if len > 1 then Just len else Nothing
            foldMsgBodies :: (GroupMember, Connection) -> (Maybe Int, ([GroupMemberId], [Either ChatError ChatMsgReq])) -> (Maybe Int, ([GroupMemberId], [Either ChatError ChatMsgReq]))
            foldMsgBodies (GroupMember {groupMemberId}, conn) (memIdx_, memIdsReqs) =
              (subtract 1 <$> memIdx_,) $ snd $ foldr' addBody (lastRef, memIdsReqs) mbs
              where
                addBody :: Either ChatError a -> (Int, ([GroupMemberId], [Either ChatError ChatMsgReq])) -> (Int, ([GroupMemberId], [Either ChatError ChatMsgReq]))
                addBody mb (i, (memIds, reqs)) =
                  let req = (conn,msgFlags,) . mkMb memIdx_ i <$> mb
                   in (i - 1, (groupMemberId : memIds, req : reqs))
        sndMessageMBR :: Maybe Int -> Int -> SndMessage -> (ValueOrRef MsgBody, [MessageId])
        sndMessageMBR memIdx_ i SndMessage {msgId, msgBody} = (vrValue_ memIdx_ i msgBody, [msgId])
        msgBatchMBR :: Maybe Int -> Int -> MsgBatch -> (ValueOrRef MsgBody, [MessageId])
        msgBatchMBR memIdx_ i (MsgBatch batchBody sndMsgs) = (vrValue_ memIdx_ i batchBody, map (\SndMessage {msgId} -> msgId) sndMsgs)
        vrValue_ memIdx_ i v = case memIdx_ of
          Nothing -> VRValue Nothing v -- sending to one member, do not reference bodies
          Just 1 -> VRValue (Just i) v
          Just _ -> VRRef i
    preparePending :: NonEmpty (Either ChatError SndMessage) -> [GroupMember] -> ([GroupMemberId], [Either ChatError (GroupMemberId, MessageId)])
    preparePending msgs_ =
      foldr' foldMsgs ([], [])
      where
        foldMsgs :: GroupMember -> ([GroupMemberId], [Either ChatError (GroupMemberId, MessageId)]) -> ([GroupMemberId], [Either ChatError (GroupMemberId, MessageId)])
        foldMsgs GroupMember {groupMemberId} memIdsReqs =
          foldr' (\msg_ (memIds, reqs) -> (groupMemberId : memIds, fmap pendingReq msg_ : reqs)) memIdsReqs msgs_
          where
            pendingReq :: SndMessage -> (GroupMemberId, MessageId)
            pendingReq SndMessage {msgId} = (groupMemberId, msgId)
    createPendingMsg :: DB.Connection -> (GroupMemberId, MessageId) -> IO (Either ChatError ())
    createPendingMsg db (groupMemberId, msgId) =
      createPendingGroupMessage db groupMemberId msgId $> Right ()

data MemberSendAction = MSASend Connection | MSASendBatched Connection | MSAPending | MSAForwarded

memberSendAction :: GroupInfo -> NonEmpty (ChatMsgEvent e) -> [GroupMember] -> GroupMember -> Maybe MemberSendAction
memberSendAction gInfo@GroupInfo {membership} events members m@GroupMember {memberRole, memberStatus}
  -- groups with relays require newer version - we don't need to check member version for batching and forwarding support
  | useRelays' gInfo =
      if
        -- if user is chat relay, send to all non chat relay members
        | isRelay membership && not (isRelay m) -> MSASendBatched . snd <$> readyMemberConn m
        -- if user is not chat relay, send only to chat relays
        | not (isRelay membership) && isRelay m -> MSASendBatched . snd <$> readyMemberConn m
        | otherwise -> Nothing -- TODO [relays] MSAForwarded to create GSSForwarded snd statuses?
  | otherwise = case memberConn m of
      Nothing -> pendingOrForwarded
      Just conn@Connection {connStatus}
        | connDisabled conn || connStatus == ConnDeleted || isConnFailed connStatus || memberStatus == GSMemRejected -> Nothing
        | connInactive conn -> Just MSAPending
        | connStatus == ConnSndReady || connStatus == ConnReady -> sendBatchedOrSeparate conn
        | otherwise -> pendingOrForwarded
  where
    sendBatchedOrSeparate conn
      -- admin doesn't support batch forwarding - send messages separately so that admin can forward one by one
      | memberRole >= GRAdmin && not (m `supportsVersion` batchSend2Version) = Just (MSASend conn)
      -- either member is not admin, or admin supports batched forwarding
      | otherwise = Just (MSASendBatched conn)
    pendingOrForwarded = case memberCategory m of
      GCUserMember -> Nothing -- shouldn't happen
      GCInviteeMember -> Just MSAPending
      GCHostMember -> Just MSAPending
      GCPreMember -> forwardSupportedOrPending (invitedByGroupMemberId membership)
      GCPostMember -> forwardSupportedOrPending (invitedByGroupMemberId m)
      where
        forwardSupportedOrPending invitingMemberId_
          | membersSupport && all isForwardedGroupMsg events = Just MSAForwarded
          | any isXGrpMsgForward events = Nothing
          | otherwise = Just MSAPending
          where
            membersSupport =
              m `supportsVersion` groupForwardVersion && invitingMemberSupportsForward
            invitingMemberSupportsForward = case invitingMemberId_ of
              Just invMemberId ->
                -- can be optimized for large groups by replacing [GroupMember] with Map GroupMemberId GroupMember
                case find (\m' -> groupMemberId' m' == invMemberId) members of
                  Just invitingMember -> invitingMember `supportsVersion` groupForwardVersion
                  Nothing -> False
              Nothing -> False
            isXGrpMsgForward event = case event of
              XGrpMsgForward {} -> True
              _ -> False

-- Should match memberSendAction logic
readyMemberConn :: GroupMember -> Maybe (GroupMemberId, Connection)
readyMemberConn GroupMember {groupMemberId, activeConn = Just conn@Connection {connStatus}, memberStatus}
  | (connStatus == ConnReady || connStatus == ConnSndReady)
      && not (connDisabled conn)
      && not (connInactive conn)
      && memberStatus /= GSMemRejected =
      Just (groupMemberId, conn)
  | otherwise = Nothing
readyMemberConn GroupMember {activeConn = Nothing} = Nothing

sendGroupMemberMessage :: MsgEncodingI e => GroupInfo -> GroupMember -> ChatMsgEvent e -> CM ()
sendGroupMemberMessage gInfo@GroupInfo {groupId} m@GroupMember {groupMemberId} chatMsgEvent = do
  msg <- createSndMessage chatMsgEvent (GroupId groupId)
  messageMember msg `catchAllErrors` eToView
  where
    messageMember :: SndMessage -> CM ()
    messageMember SndMessage {msgId, msgBody} = forM_ (memberSendAction gInfo (chatMsgEvent :| []) [m] m) $ \case
      MSASend conn -> void $ deliverMessage conn (toCMEventTag chatMsgEvent) msgBody msgId
      MSASendBatched conn -> void $ deliverMessage conn (toCMEventTag chatMsgEvent) msgBody msgId
      MSAPending -> withStore' $ \db -> createPendingGroupMessage db groupMemberId msgId
      MSAForwarded -> pure ()

-- Send pre-encoded forwarded message preserving original signature
sendFwdMemberMessage :: GroupMember -> GrpMsgForward -> VerifiedMsg 'Json -> CM ()
sendFwdMemberMessage member fwd verifiedMsg =
  forM_ (readyMemberConn member) $ \(_, conn) -> do
    let body = encodeBinaryBatch [encodeFwdElement fwd verifiedMsg]
    void $ withAgent $ \a -> sendMessages a [(aConnId conn, PQEncOff, MsgFlags False, VRValue Nothing body)]

-- TODO ensure order - pending messages interleave with user input messages
sendPendingGroupMessages :: User -> GroupInfo -> GroupMember -> Connection -> CM ()
sendPendingGroupMessages user gInfo GroupMember {groupMemberId} conn = do
  let mode = if useRelays' gInfo then BMBinary else BMJson
  msgs <- withStore' $ \db -> getPendingGroupMessages db groupMemberId
  forM_ (L.nonEmpty msgs) $ \msgs' -> do
    void $ batchSendConnMessages mode user conn MsgFlags {notification = True} msgs'
    lift . void . withStoreBatch' $ \db -> L.map (\SndMessage {msgId} -> deletePendingGroupMessage db groupMemberId msgId) msgs'

saveDirectRcvMSG :: forall e. MsgEncodingI e => Connection -> MsgMeta -> ChatMessage e -> CM (Connection, RcvMessage)
saveDirectRcvMSG conn@Connection {connId} agentMsgMeta chatMsg@ChatMessage {chatVRange, msgId = sharedMsgId_, chatMsgEvent} = do
  conn' <- updatePeerChatVRange conn chatVRange
  let agentMsgId = fst $ recipient agentMsgMeta
      brokerTs = metaBrokerTs agentMsgMeta
      newMsg = NewRcvMessage {chatMsgEvent, verifiedMsg = VMUnsigned chatMsg, brokerTs}
      rcvMsgDelivery = RcvMsgDelivery {connId, agentMsgId, agentMsgMeta}
  msg <- withStore $ \db -> createNewMessageAndRcvMsgDelivery db (ConnectionId connId) newMsg sharedMsgId_ rcvMsgDelivery Nothing
  pure (conn', msg)

saveGroupRcvMsg :: forall e. MsgEncodingI e => User -> GroupId -> GroupMember -> Connection -> MsgMeta -> VerifiedMsg e -> CM (GroupMember, Connection, RcvMessage)
saveGroupRcvMsg user groupId authorMember conn@Connection {connId} agentMsgMeta verifiedMsg = do
  let ChatMessage {chatVRange, msgId = sharedMsgId_, chatMsgEvent} = verifiedChatMsg verifiedMsg
  -- binary messages (file chunks) carry only the initial-version sentinel, not the sender's range;
  -- applying it would downgrade the member's negotiated version and suppress version-gated delivery
  (am'@GroupMember {memberId = amMemId, groupMemberId = amGroupMemId}, conn') <- case encoding @e of
    SBinary -> pure (authorMember, conn)
    SJson -> updateMemberChatVRange authorMember conn chatVRange
  let agentMsgId = fst $ recipient agentMsgMeta
      brokerTs = metaBrokerTs agentMsgMeta
      newMsg = NewRcvMessage {chatMsgEvent, verifiedMsg, brokerTs}
      rcvMsgDelivery = RcvMsgDelivery {connId, agentMsgId, agentMsgMeta}
  msg <-
    withStore (\db -> createNewMessageAndRcvMsgDelivery db (GroupId groupId) newMsg sharedMsgId_ rcvMsgDelivery $ Just amGroupMemId)
      `catchAllErrors` \e -> case e of
        ChatErrorStore (SEDuplicateGroupMessage _ _ _ (Just forwardedByGroupMemberId)) -> do
          cxt <- chatStoreCxt
          fm <- withStore $ \db -> getGroupMember db cxt user groupId forwardedByGroupMemberId
          forM_ (memberConn fm) $ \fmConn ->
            void $ sendDirectMemberMessage fmConn (XGrpMemCon amMemId) groupId
          throwError e
        _ -> throwError e
  pure (am', conn', msg)

saveGroupFwdRcvMsg :: MsgEncodingI e => User -> GroupInfo -> GroupMember -> Maybe GroupMember -> VerifiedMsg e -> UTCTime -> CM (Maybe RcvMessage)
saveGroupFwdRcvMsg user gInfo@GroupInfo {groupId} forwardingMember refAuthorMember_ verifiedMsg brokerTs = do
  let ChatMessage {msgId = sharedMsgId_, chatMsgEvent} = verifiedChatMsg verifiedMsg
      newMsg = NewRcvMessage {chatMsgEvent, verifiedMsg, brokerTs}
      fwdMemberId = Just $ groupMemberId' forwardingMember
      refAuthorId = groupMemberId' <$> refAuthorMember_
  -- TODO [relays] TBC highlighting difference between deduplicated messages (useRelays branch)
  withStore' (\db -> runExceptT $ createNewRcvMessage db (GroupId groupId) newMsg sharedMsgId_ refAuthorId fwdMemberId) >>= \case
    Right msg -> pure $ Just msg
    Left e@SEDuplicateGroupMessage {authorGroupMemberId, forwardedByGroupMemberId}
      | useRelays' gInfo -> pure Nothing -- with chat relays, duplicates are expected
      | otherwise -> case (authorGroupMemberId, forwardedByGroupMemberId) of
          (Just authorGMId, Nothing) -> do
            cxt <- chatStoreCxt
            am@GroupMember {memberId = amMemberId} <- withStore $ \db -> getGroupMember db cxt user groupId authorGMId
            if maybe False (\ref -> sameMemberId (memberId' ref) am) refAuthorMember_
              then forM_ (memberConn forwardingMember) $ \fmConn ->
                void $ sendDirectMemberMessage fmConn (XGrpMemCon amMemberId) groupId
              else toView $ CEvtMessageError user "error" "saveGroupFwdRcvMsg: referenced author member id doesn't match message member id"
            throwError $ ChatErrorStore e
          _ -> throwError $ ChatErrorStore e
    Left e -> throwError $ ChatErrorStore e

saveSndChatItem :: ChatTypeI c => User -> ChatDirection c 'MDSnd -> SndMessage -> CIContent 'MDSnd -> CM (ChatItem c 'MDSnd)
saveSndChatItem user cd msg content = saveSndChatItem' user cd msg content Nothing Nothing Nothing Nothing False

-- TODO [mentions] optimize by avoiding unnecesary parsing of control messages
saveSndChatItem' :: ChatTypeI c => User -> ChatDirection c 'MDSnd -> SndMessage -> CIContent 'MDSnd -> Maybe (CIFile 'MDSnd) -> Maybe (CIQuote c) -> Maybe CIForwardedFrom -> Maybe CITimed -> Bool -> CM (ChatItem c 'MDSnd)
saveSndChatItem' user cd msg content ciFile quotedItem itemForwarded itemTimed live = do
  let itemTexts = ciContentTexts content
  saveSndChatItems user cd False [Right NewSndChatItemData {msg, content, itemTexts, itemMentions = M.empty, ciFile, quotedItem, itemForwarded}] itemTimed live >>= \case
    [Right ci] -> pure ci
    _ -> throwChatError $ CEInternalError "saveSndChatItem': expected 1 item"

data NewSndChatItemData c = NewSndChatItemData
  { msg :: SndMessage,
    content :: CIContent 'MDSnd,
    itemTexts :: (Text, Maybe MarkdownList),
    itemMentions :: Map MemberName CIMention,
    ciFile :: Maybe (CIFile 'MDSnd),
    quotedItem :: Maybe (CIQuote c),
    itemForwarded :: Maybe CIForwardedFrom
  }

saveSndChatItems ::
  forall c.
  ChatTypeI c =>
  User ->
  ChatDirection c 'MDSnd ->
  ShowGroupAsSender ->
  [Either ChatError (NewSndChatItemData c)] ->
  Maybe CITimed ->
  Bool ->
  CM [Either ChatError (ChatItem c 'MDSnd)]
saveSndChatItems user cd showGroupAsSender itemsData itemTimed live = do
  createdAt <- liftIO getCurrentTime
  cxt <- chatStoreCxt
  when (contactChatDeleted cd || any (\NewSndChatItemData {content} -> ciRequiresAttention content) (rights itemsData)) $
    void (withStore' $ \db -> updateChatTsStats db cxt user cd createdAt Nothing)
  lift $ withStoreBatch (\db -> map (bindRight $ createItem db createdAt) itemsData)
  where
    createItem :: DB.Connection -> UTCTime -> NewSndChatItemData c -> IO (Either ChatError (ChatItem c 'MDSnd))
    createItem db createdAt NewSndChatItemData {msg = msg@SndMessage {sharedMsgId, signedMsg_}, content, itemTexts, itemMentions, ciFile, quotedItem, itemForwarded} = do
      let hasLink_ = ciContentHasLink content (snd itemTexts)
      ciId <- createNewSndChatItem db user cd showGroupAsSender msg content quotedItem itemForwarded itemTimed live hasLink_ createdAt
      forM_ ciFile $ \CIFile {fileId} -> updateFileTransferChatItemId db fileId ciId createdAt
      let ci = mkChatItem_ cd showGroupAsSender ciId content itemTexts ciFile quotedItem (Just sharedMsgId) itemForwarded itemTimed live False hasLink_ createdAt Nothing (toMsgVerified (signMessagesRequired cd) (MSSVerified <$ signedMsg_)) createdAt
      Right <$> case cd of
        CDGroupSnd g _scope | not (null itemMentions) -> createGroupCIMentions db g ci itemMentions
        _ -> pure ci

saveRcvChatItemNoParse :: (ChatTypeI c, ChatTypeQuotable c) => User -> ChatDirection c 'MDRcv -> RcvMessage -> UTCTime -> CIContent 'MDRcv -> CM (ChatItem c 'MDRcv, ChatInfo c)
saveRcvChatItemNoParse user cd msg brokerTs = saveRcvChatItem user cd msg brokerTs . ciContentNoParse

saveRcvChatItem :: (ChatTypeI c, ChatTypeQuotable c) => User -> ChatDirection c 'MDRcv -> RcvMessage -> UTCTime -> (CIContent 'MDRcv, (Text, Maybe MarkdownList)) -> CM (ChatItem c 'MDRcv, ChatInfo c)
saveRcvChatItem user cd msg@RcvMessage {sharedMsgId_} brokerTs content =
  saveRcvChatItem' user cd msg sharedMsgId_ brokerTs content Nothing Nothing False M.empty

ciContentNoParse :: CIContent 'MDRcv -> (CIContent 'MDRcv, (Text, Maybe MarkdownList))
ciContentNoParse content = (content, (ciContentToText content, Nothing))

saveRcvChatItem' :: (ChatTypeI c, ChatTypeQuotable c) => User -> ChatDirection c 'MDRcv -> RcvMessage -> Maybe SharedMsgId -> UTCTime -> (CIContent 'MDRcv, (Text, Maybe MarkdownList)) -> Maybe (CIFile 'MDRcv) -> Maybe CITimed -> Bool -> Map MemberName MsgMention -> CM (ChatItem c 'MDRcv, ChatInfo c)
saveRcvChatItem' user cd msg@RcvMessage {chatMsgEvent, msgSigned, forwardedByMember} sharedMsgId_ brokerTs (content, (t, ft_)) ciFile itemTimed live mentions = do
  createdAt <- liftIO getCurrentTime
  cxt <- chatStoreCxt
  withStore' $ \db -> do
    (mentions' :: Map MemberName CIMention, userMention) <- case toChatInfo cd of
      GroupChat g@GroupInfo {membership} _ -> groupMentions db g membership
      _ -> pure (M.empty, False)
    cInfo' <-
      if (ciRequiresAttention content || contactChatDeleted cd)
        then updateChatTsStats db cxt user cd createdAt (memberChatStats userMention)
        else pure $ toChatInfo cd
    let showAsGroup = case cd of CDChannelRcv {} -> True; _ -> False
        hasLink_ = ciContentHasLink content ft_
    (ciId, quotedItem, itemForwarded) <- createNewRcvChatItem db user cd msg sharedMsgId_ content itemTimed live userMention hasLink_ brokerTs createdAt
    forM_ ciFile $ \CIFile {fileId} -> updateFileTransferChatItemId db fileId ciId createdAt
    let ci = mkChatItem_ cd showAsGroup ciId content (t, ft_) ciFile quotedItem sharedMsgId_ itemForwarded itemTimed live userMention hasLink_ brokerTs forwardedByMember (toMsgVerified (signMessagesRequired cd) msgSigned) createdAt
    ci' <- case toChatInfo cd of
      GroupChat g _ | not (null mentions') -> createGroupCIMentions db g ci mentions'
      _ -> pure ci
    pure (ci', cInfo')
  where
    groupMentions db g membership = do
      mentions' <- getRcvCIMentions db user g ft_ mentions
      -- messages of blocked members are hidden, they should not mention user
      let senderBlocked = case cd of
            CDGroupRcv _g _scope m -> memberBlocked m
            _ -> False
          userReply = not senderBlocked && case cmToQuotedMsg chatMsgEvent of
            Just QuotedMsg {msgRef = MsgRef {memberId = Just mId}} -> sameMemberId mId membership
            _ -> False
          userMention' = userReply || any (\CIMention {memberId} -> sameMemberId memberId membership) mentions'
       in pure (mentions', userMention')
    memberChatStats :: Bool -> Maybe (Int, MemberAttention, Int)
    memberChatStats userMention = case cd of
      CDGroupRcv _g (Just scope) m ->
        let unread = fromEnum $ ciCreateStatus content == CISRcvNew
         in Just (unread, memberAttentionChange unread (Just brokerTs) (Just m) scope, fromEnum userMention)
      CDChannelRcv _g (Just scope) ->
        let unread = fromEnum $ ciCreateStatus content == CISRcvNew
         in Just (unread, memberAttentionChange unread (Just brokerTs) Nothing scope, fromEnum userMention)
      _ -> Nothing

-- TODO [mentions] optimize by avoiding unnecessary parsing
mkChatItem :: (ChatTypeI c, MsgDirectionI d) => ChatDirection c d -> ShowGroupAsSender -> ChatItemId -> CIContent d -> Maybe (CIFile d) -> Maybe (CIQuote c) -> Maybe SharedMsgId -> Maybe CIForwardedFrom -> Maybe CITimed -> Bool -> Bool -> ChatItemTs -> Maybe GroupMemberId -> Maybe MsgVerified -> UTCTime -> ChatItem c d
mkChatItem cd showGroupAsSender ciId content file quotedItem sharedMsgId itemForwarded itemTimed live userMention itemTs forwardedByMember msgVerified currentTs =
  let ts@(_, ft_) = ciContentTexts content
      hasLink_ = ciContentHasLink content ft_
   in mkChatItem_ cd showGroupAsSender ciId content ts file quotedItem sharedMsgId itemForwarded itemTimed live userMention hasLink_ itemTs forwardedByMember msgVerified currentTs

mkChatItem_ :: (ChatTypeI c, MsgDirectionI d) => ChatDirection c d -> ShowGroupAsSender -> ChatItemId -> CIContent d -> (Text, Maybe MarkdownList) -> Maybe (CIFile d) -> Maybe (CIQuote c) -> Maybe SharedMsgId -> Maybe CIForwardedFrom -> Maybe CITimed -> Bool -> Bool -> Bool -> ChatItemTs -> Maybe GroupMemberId -> Maybe MsgVerified -> UTCTime -> ChatItem c d
mkChatItem_ cd showGroupAsSender ciId content (itemText, formattedText) file quotedItem sharedMsgId itemForwarded itemTimed live userMention hasLink_ itemTs forwardedByMember msgVerified currentTs =
  let itemStatus = ciCreateStatus content
      meta = mkCIMeta ciId content itemText itemStatus Nothing sharedMsgId itemForwarded Nothing False itemTimed (justTrue live) userMention hasLink_ currentTs itemTs forwardedByMember showGroupAsSender msgVerified currentTs currentTs
   in ChatItem {chatDir = toCIDirection cd, meta, content, mentions = M.empty, formattedText, quotedItem, reactions = [], file}

ciContentHasLink :: CIContent d -> Maybe MarkdownList -> Bool
ciContentHasLink content ft_ = case ciMsgContent content of
  Just mc -> msgContentHasLink mc ft_
  Nothing -> False

msgContentHasLink :: MsgContent -> Maybe MarkdownList -> Bool
msgContentHasLink mc ft_ = case msgContentTag mc of
  MCLink_ -> True
  _ -> maybe False hasLinks ft_

prepareAgentCreation :: ConnectionModeI c => User -> CommandFunction -> Bool -> SConnectionMode c -> CM (CommandId, ConnId)
prepareAgentCreation user cmdFunction enableNtfs cMode = do
  cmdId <- withStore' $ \db -> createCommand db user Nothing cmdFunction
  connId <- withAgent $ \a -> prepareConnectionToCreate a (aUserId user) enableNtfs cMode PQSupportOff
  pure (cmdId, connId)

prepareAgentJoin :: User -> Maybe Connection -> Bool -> ConnectionRequestUri c -> CM (CommandId, ConnId)
prepareAgentJoin user conn_ enableNtfs cReqUri = do
  cmdId <- withStore' $ \db -> createCommand db user (dbConnId <$> conn_) CFJoinConn
  connId <- case conn_ of
    Just conn -> pure $ aConnId conn
    Nothing -> withAgent $ \a -> prepareConnectionToJoin a (aUserId user) enableNtfs cReqUri PQSupportOff
  pure (cmdId, connId)

joinAgentConnectionAsync :: ConnectionModeI c => CommandId -> Bool -> ConnId -> Bool -> ConnectionRequestUri c -> ConnInfo -> SubscriptionMode -> CM ()
joinAgentConnectionAsync cmdId updateConn connId enableNtfs cReqUri cInfo subMode =
  withAgent $ \a -> joinConnectionAsync a (aCorrId cmdId) updateConn connId enableNtfs cReqUri cInfo PQSupportOff subMode

allowAgentConnectionAsync :: MsgEncodingI e => User -> Connection -> ConfirmationId -> ChatMsgEvent e -> CM ()
allowAgentConnectionAsync user conn@Connection {connId, pqSupport, connChatVersion} confId msg = do
  cmdId <- withStore' $ \db -> createCommand db user (Just connId) CFAllowConn
  dm <- encodeConnInfoPQ pqSupport connChatVersion msg
  withAgent $ \a -> allowConnectionAsync a (aCorrId cmdId) (aConnId conn) confId dm
  withStore' $ \db -> updateConnectionStatus db conn ConnAccepted

prepareAgentAccept :: User -> Bool -> InvitationId -> PQSupport -> CM (CommandId, ConnId)
prepareAgentAccept user enableNtfs invId pqSup = do
  cmdId <- withStore' $ \db -> createCommand db user Nothing CFAcceptContact
  connId <- withAgent $ \a -> prepareConnectionToAccept a (aUserId user) enableNtfs invId pqSup
  pure (cmdId, connId)

agentAcceptContactAsync :: MsgEncodingI e => CommandId -> ConnId -> Bool -> InvitationId -> ChatMsgEvent e -> PQSupport -> VersionChat -> SubscriptionMode -> CM ()
agentAcceptContactAsync cmdId connId enableNtfs invId msg pqSup chatV subMode = do
  dm <- encodeConnInfoPQ pqSup chatV msg
  withAgent $ \a -> acceptContactAsync a (aCorrId cmdId) connId enableNtfs invId dm pqSup subMode

deleteAgentConnectionAsync :: ConnId -> CM ()
deleteAgentConnectionAsync acId = deleteAgentConnectionAsync' acId False
{-# INLINE deleteAgentConnectionAsync #-}

deleteAgentConnectionAsync' :: ConnId -> Bool -> CM ()
deleteAgentConnectionAsync' acId waitDelivery = do
  withAgent (\a -> deleteConnectionAsync a waitDelivery acId) `catchAllErrors` eToView

deleteAgentConnectionsAsync :: [ConnId] -> CM ()
deleteAgentConnectionsAsync acIds = deleteAgentConnectionsAsync' acIds False
{-# INLINE deleteAgentConnectionsAsync #-}

deleteAgentConnectionsAsync' :: [ConnId] -> Bool -> CM ()
deleteAgentConnectionsAsync' [] _ = pure ()
deleteAgentConnectionsAsync' acIds waitDelivery = do
  withAgent (\a -> deleteConnectionsAsync a waitDelivery acIds) `catchAllErrors` eToView

setAgentConnShortLinkAsync :: User -> Connection -> UserConnLinkData 'CMContact -> Maybe CRClientData -> CM ()
setAgentConnShortLinkAsync user conn@Connection {connId} userLinkData crClientData_ = do
  cmdId <- withStore' $ \db -> createCommand db user (Just connId) CFSetShortLink
  withAgent $ \a -> setConnShortLinkAsync a (aCorrId cmdId) (aConnId conn) userLinkData crClientData_

getAgentConnShortLinkAsync :: User -> CommandFunction -> Maybe Connection -> ShortLinkContact -> CM (CommandId, ConnId)
getAgentConnShortLinkAsync user cmdFunc conn_ shortLink = do
  shortLink' <- restoreShortLink' shortLink
  cmdId <- withStore' $ \db -> createCommand db user (dbConnId <$> conn_) cmdFunc
  connId <- withAgent $ \a -> getConnShortLinkAsync a (aUserId user) (aCorrId cmdId) (aConnId <$> conn_) shortLink'
  pure (cmdId, connId)

agentXFTPDeleteRcvFile :: RcvFileId -> FileTransferId -> CM ()
agentXFTPDeleteRcvFile aFileId fileId = do
  lift $ withAgent' (`xftpDeleteRcvFile` aFileId)
  withStore' $ \db -> setRcvFTAgentDeleted db fileId

agentXFTPDeleteRcvFiles :: [(XFTPRcvFile, FileTransferId)] -> CM' ()
agentXFTPDeleteRcvFiles rcvFiles = do
  let rcvFiles' = filter (not . agentRcvFileDeleted . fst) rcvFiles
      rfIds = mapMaybe fileIds rcvFiles'
  withAgent' $ \a -> xftpDeleteRcvFiles a (map fst rfIds)
  void . withStoreBatch' $ \db -> map (setRcvFTAgentDeleted db . snd) rfIds
  where
    fileIds :: (XFTPRcvFile, FileTransferId) -> Maybe (RcvFileId, FileTransferId)
    fileIds (XFTPRcvFile {agentRcvFileId = Just (AgentRcvFileId aFileId)}, fileId) = Just (aFileId, fileId)
    fileIds _ = Nothing

agentXFTPDeleteSndFileRemote :: User -> XFTPSndFile -> FileTransferId -> CM' ()
agentXFTPDeleteSndFileRemote user xsf fileId =
  agentXFTPDeleteSndFilesRemote user [(xsf, fileId)]

agentXFTPDeleteSndFilesRemote :: User -> [(XFTPSndFile, FileTransferId)] -> CM' ()
agentXFTPDeleteSndFilesRemote user sndFiles = do
  (_errs, redirects) <- partitionEithers <$> withStoreBatch' (\db -> map (lookupFileTransferRedirectMeta db user . snd) sndFiles)
  let redirects' = mapMaybe mapRedirectMeta $ concat redirects
      sndFilesAll = redirects' <> sndFiles
      sndFilesAll' = filter (not . agentSndFileDeleted . fst) sndFilesAll
  -- while file is being prepared and uploaded, it would not have description available;
  -- this partitions files into those with and without descriptions -
  -- files with description are deleted remotely, files without description are deleted internally
  (sfsNoDescr, sfsWithDescr) <- partitionSndDescr sndFilesAll' [] []
  withAgent' $ \a -> xftpDeleteSndFilesInternal a sfsNoDescr
  withAgent' $ \a -> xftpDeleteSndFilesRemote a (aUserId user) sfsWithDescr
  void . withStoreBatch' $ \db -> map (setSndFTAgentDeleted db user . snd) sndFilesAll'
  where
    mapRedirectMeta :: FileTransferMeta -> Maybe (XFTPSndFile, FileTransferId)
    mapRedirectMeta FileTransferMeta {fileId = fileId, xftpSndFile = Just sndFileRedirect} = Just (sndFileRedirect, fileId)
    mapRedirectMeta _ = Nothing
    partitionSndDescr ::
      [(XFTPSndFile, FileTransferId)] ->
      [SndFileId] ->
      [(SndFileId, ValidFileDescription 'FSender)] ->
      CM' ([SndFileId], [(SndFileId, ValidFileDescription 'FSender)])
    partitionSndDescr [] filesWithoutDescr filesWithDescr = pure (filesWithoutDescr, filesWithDescr)
    partitionSndDescr ((XFTPSndFile {agentSndFileId = AgentSndFileId aFileId, privateSndFileDescr}, _) : xsfs) filesWithoutDescr filesWithDescr =
      case privateSndFileDescr of
        Nothing -> partitionSndDescr xsfs (aFileId : filesWithoutDescr) filesWithDescr
        Just sfdText ->
          tryAllErrors' (parseFileDescription sfdText) >>= \case
            Left _ -> partitionSndDescr xsfs (aFileId : filesWithoutDescr) filesWithDescr
            Right sfd -> partitionSndDescr xsfs filesWithoutDescr ((aFileId, sfd) : filesWithDescr)

connRequestPQEncryption :: ConnectionRequestUri c -> Maybe PQEncryption
connRequestPQEncryption = \case
  CRContactUri _ -> Nothing
  CRInvitationUri _ (CR.E2ERatchetParamsUri vr' _ _ pq) ->
    Just $ PQEncryption $ maxVersion vr' >= CR.pqRatchetE2EEncryptVersion && isJust pq

createRcvFeatureItems :: User -> Contact -> Contact -> CM' ()
createRcvFeatureItems user ct ct' =
  createFeatureItems user ct ct' CDDirectRcv CIRcvChatFeature CIRcvChatPreference contactPreference

createSndFeatureItems :: User -> Contact -> Contact -> CM' ()
createSndFeatureItems user ct ct' =
  createFeatureItems user ct ct' CDDirectSnd CISndChatFeature CISndChatPreference getPref
  where
    getPref ContactUserPreference {userPreference} = case userPreference of
      CUPContact {preference} -> preference
      CUPUser {preference} -> preference

-- Used when contact is changed after creating initial feature items via createFeatureEnabledItems_
-- (APIChangePreparedContactUser, APIConnectPreparedContact with incognito = True);
-- creates feature items with CDDirectRcv direction so that changed feature items stay in the same place in chat view
createContactChangedFeatureItems :: User -> Contact -> Contact -> CM' ()
createContactChangedFeatureItems user ct ct' =
  createFeatureItems user ct ct' CDDirectRcv CIRcvChatFeature CIRcvChatPreference getPref
  where
    getPref ContactUserPreference {userPreference} = case userPreference of
      CUPContact {preference} -> preference
      CUPUser {preference} -> preference

type FeatureContent a d = ChatFeature -> a -> Maybe Int -> CIContent d

createFeatureEnabledItems :: User -> Contact -> CM ()
createFeatureEnabledItems user ct = createFeatureEnabledItems_ user ct >>= toView . CEvtNewChatItems user

createFeatureEnabledItems_ :: User -> Contact -> CM [AChatItem]
createFeatureEnabledItems_ user ct@Contact {mergedPreferences} =
  forM allChatFeatures $ \(ACF f) -> do
    let state = featureState $ getContactUserPreference f mergedPreferences
    createChatItem user (CDDirectRcv ct) False (uncurry (CIRcvChatFeature $ chatFeature f) state) Nothing Nothing Nothing

createFeatureItems ::
  MsgDirectionI d =>
  User ->
  Contact ->
  Contact ->
  (Contact -> ChatDirection 'CTDirect d) ->
  FeatureContent PrefEnabled d ->
  FeatureContent FeatureAllowed d ->
  (forall f. ContactUserPreference (FeaturePreference f) -> FeaturePreference f) ->
  CM' ()
createFeatureItems user ct ct' = createContactsFeatureItems user [(ct, ct')]

createContactsFeatureItems ::
  forall d.
  MsgDirectionI d =>
  User ->
  [(Contact, Contact)] ->
  (Contact -> ChatDirection 'CTDirect d) ->
  FeatureContent PrefEnabled d ->
  FeatureContent FeatureAllowed d ->
  (forall f. ContactUserPreference (FeaturePreference f) -> FeaturePreference f) ->
  CM' ()
createContactsFeatureItems user cts chatDir ciFeature ciOffer getPref = do
  let dirsCIContents = map contactChangedFeatures cts
  (errs, acis) <- partitionEithers <$> createChatItems user Nothing dirsCIContents
  unless (null errs) $ toView' $ CEvtChatErrors errs
  toView' $ CEvtNewChatItems user acis
  where
    contactChangedFeatures :: (Contact, Contact) -> (ChatDirection 'CTDirect d, ShowGroupAsSender, [(CIContent d, Maybe SharedMsgId, Maybe MsgSigStatus)])
    contactChangedFeatures (Contact {mergedPreferences = cups}, ct'@Contact {mergedPreferences = cups'}) = do
      let contents = mapMaybe (\(ACF f) -> featureCIContent_ f) allChatFeatures
      (chatDir ct', False, contents)
      where
        featureCIContent_ :: forall f. FeatureI f => SChatFeature f -> Maybe (CIContent d, Maybe SharedMsgId, Maybe MsgSigStatus)
        featureCIContent_ f
          | state /= state' = Just (fContent ciFeature state', Nothing, Nothing)
          | prefState /= prefState' = Just (fContent ciOffer prefState', Nothing, Nothing)
          | otherwise = Nothing
          where
            fContent :: FeatureContent a d -> (a, Maybe Int) -> CIContent d
            fContent ci (s, param) = ci f' s param
            f' = chatFeature f
            state = featureState cup
            state' = featureState cup'
            prefState = preferenceState $ getPref cup
            prefState' = preferenceState $ getPref cup'
            cup = getContactUserPreference f cups
            cup' = getContactUserPreference f cups'

groupFeatures :: GroupInfo -> [AGroupFeature]
groupFeatures g = if useRelays' g then channelGroupFeatures else regularGroupFeatures

createGroupFeatureChangedItems :: MsgDirectionI d => User -> ChatDirection 'CTGroup d -> (GroupFeature -> GroupPreference -> Maybe Int -> Maybe GroupMemberRole -> CIContent d) -> GroupInfo -> GroupInfo -> CM ()
createGroupFeatureChangedItems user cd ciContent GroupInfo {fullGroupPreferences = gps} g'@GroupInfo {fullGroupPreferences = gps'} =
  forM_ (groupFeatures g') $ \(AGF f) -> do
    let state = groupFeatureState $ getGroupPreference f gps
        pref' = getGroupPreference f gps'
        state'@(_, param', role') = groupFeatureState pref'
    when (state /= state') $
      createInternalChatItem user cd (ciContent (toGroupFeature f) (toGroupPreference pref') param' role') Nothing

sameGroupProfileInfo :: GroupProfile -> GroupProfile -> Bool
sameGroupProfileInfo p p' = p {groupPreferences = Nothing} == p' {groupPreferences = Nothing}

createGroupFeatureItems :: MsgDirectionI d => User -> ChatDirection 'CTGroup d -> (GroupFeature -> GroupPreference -> Maybe Int -> Maybe GroupMemberRole -> CIContent d) -> GroupInfo -> CM ()
createGroupFeatureItems user cd ciContent g = createGroupFeatureItems_ user cd False ciContent g >>= toView . CEvtNewChatItems user

createGroupFeatureItems_ :: MsgDirectionI d => User -> ChatDirection 'CTGroup d -> ShowGroupAsSender -> (GroupFeature -> GroupPreference -> Maybe Int -> Maybe GroupMemberRole -> CIContent d) -> GroupInfo -> CM [AChatItem]
createGroupFeatureItems_ user cd showGroupAsSender ciContent g@GroupInfo {fullGroupPreferences} =
  forM (groupFeatures g) $ \(AGF f) -> do
    let p = getGroupPreference f fullGroupPreferences
        (_, param, role) = groupFeatureState p
    createChatItem user cd showGroupAsSender (ciContent (toGroupFeature f) (toGroupPreference p) param role) Nothing Nothing Nothing

createInternalChatItem :: (ChatTypeI c, MsgDirectionI d) => User -> ChatDirection c d -> CIContent d -> Maybe UTCTime -> CM ()
createInternalChatItem user cd content itemTs_ = do
  ci <- createChatItem user cd False content Nothing Nothing itemTs_
  toView $ CEvtNewChatItems user [ci]

createChatItem :: (ChatTypeI c, MsgDirectionI d) => User -> ChatDirection c d -> ShowGroupAsSender -> CIContent d -> Maybe SharedMsgId -> Maybe MsgSigStatus -> Maybe UTCTime -> CM AChatItem
createChatItem user cd showGroupAsSender content sharedMsgId msgSigned itemTs_ =
  lift (createChatItems user itemTs_ [(cd, showGroupAsSender, [(content, sharedMsgId, msgSigned)])]) >>= \case
    [Right ci] -> pure ci
    [Left e] -> throwError e
    rs -> throwChatError $ CEInternalError $ "createInternalChatItem: expected 1 result, got " <> show (length rs)

-- Supports items with shared msg ID that are created for all conversation parties, but were not communicated via the usual messages.
-- This includes address welcome message and contact request message.
createChatItems ::
  forall c d.
  (ChatTypeI c, MsgDirectionI d) =>
  User ->
  Maybe UTCTime ->
  [(ChatDirection c d, ShowGroupAsSender, [(CIContent d, Maybe SharedMsgId, Maybe MsgSigStatus)])] ->
  CM' [Either ChatError AChatItem]
createChatItems user itemTs_ dirsCIContents = do
  createdAt <- liftIO getCurrentTime
  let itemTs = fromMaybe createdAt itemTs_
  cxt <- chatStoreCxt'
  void . withStoreBatch' $ \db -> map (updateChat db cxt createdAt) dirsCIContents
  withStoreBatch' $ \db -> concatMap (createACIs db itemTs createdAt) dirsCIContents
  where
    updateChat :: DB.Connection -> StoreCxt -> UTCTime -> (ChatDirection c d, ShowGroupAsSender, [(CIContent d, Maybe SharedMsgId, Maybe MsgSigStatus)]) -> IO ()
    updateChat db cxt createdAt (cd, _, contents)
      | any (\(content, _, _) -> ciRequiresAttention content) contents || contactChatDeleted cd = void $ updateChatTsStats db cxt user cd createdAt memberChatStats
      | otherwise = pure ()
      where
        memberChatStats :: Maybe (Int, MemberAttention, Int)
        memberChatStats = case cd of
          CDGroupRcv _g (Just scope) m -> do
            let unread = length $ filter (\(content, _, _) -> ciRequiresAttention content) contents
             in Just (unread, memberAttentionChange unread itemTs_ (Just m) scope, 0)
          _ -> Nothing
    createACIs :: DB.Connection -> UTCTime -> UTCTime -> (ChatDirection c d, ShowGroupAsSender, [(CIContent d, Maybe SharedMsgId, Maybe MsgSigStatus)]) -> [IO AChatItem]
    createACIs db itemTs createdAt (cd, showGroupAsSender, contents) = map createACI contents
      where
        createACI (content, sharedMsgId, msgSigned) = do
          let hasLink_ = ciContentHasLink content Nothing
              msgVerified = toMsgVerified False msgSigned
          ciId <- createNewChatItemNoMsg db user cd showGroupAsSender content sharedMsgId hasLink_ msgVerified itemTs createdAt
          let ci = mkChatItem cd showGroupAsSender ciId content Nothing Nothing Nothing Nothing Nothing False False itemTs Nothing msgVerified createdAt
          pure $ AChatItem (chatTypeI @c) (msgDirection @d) (toChatInfo cd) ci

-- rcvMem_ Nothing means message from channel - treated same as message from moderator,
-- e.g. it can reset unanswered counter if newer than last unanswered message.
memberAttentionChange :: Int -> (Maybe UTCTime) -> Maybe GroupMember -> GroupChatScopeInfo -> MemberAttention
memberAttentionChange unread brokerTs_ rcvMem_ = \case
  GCSIMemberSupport (Just suppMem)
    | maybe False ((groupMemberId' suppMem ==) . groupMemberId') rcvMem_ -> MAInc unread brokerTs_
    | msgIsNewerThanLastUnanswered -> MAReset
    | otherwise -> MAInc 0 Nothing
    where
      msgIsNewerThanLastUnanswered = case (supportChat suppMem >>= lastMsgFromMemberTs, brokerTs_) of
        (Just lastMsgTs, Just brokerTs) -> lastMsgTs < brokerTs
        _ -> False
  GCSIMemberSupport Nothing -> MAInc 0 Nothing

createLocalChatItems ::
  User ->
  ChatDirection 'CTLocal 'MDSnd ->
  NonEmpty (CIContent 'MDSnd, Maybe (CIFile 'MDSnd), Maybe CIForwardedFrom, (Text, Maybe MarkdownList)) ->
  UTCTime ->
  CM [ChatItem 'CTLocal 'MDSnd]
createLocalChatItems user cd itemsData createdAt = do
  cxt <- chatStoreCxt
  void $ withStore' $ \db -> updateChatTsStats db cxt user cd createdAt Nothing
  (errs, items) <- lift $ partitionEithers <$> withStoreBatch' (\db -> map (createItem db) $ L.toList itemsData)
  unless (null errs) $ toView $ CEvtChatErrors errs
  pure items
  where
    createItem :: DB.Connection -> (CIContent 'MDSnd, Maybe (CIFile 'MDSnd), Maybe CIForwardedFrom, (Text, Maybe MarkdownList)) -> IO (ChatItem 'CTLocal 'MDSnd)
    createItem db (content, ciFile, itemForwarded, ts@(_, ft_)) = do
      let hasLink_ = ciContentHasLink content ft_
      ciId <- createNewChatItem_ db user cd False Nothing Nothing content (Nothing, Nothing, Nothing, Nothing, Nothing) itemForwarded Nothing False False hasLink_ createdAt Nothing Nothing Nothing Nothing createdAt
      forM_ ciFile $ \CIFile {fileId} -> updateFileTransferChatItemId db fileId ciId createdAt
      pure $ mkChatItem_ cd False ciId content ts ciFile Nothing Nothing itemForwarded Nothing False False hasLink_ createdAt Nothing Nothing createdAt

withUser' :: (User -> CM ChatResponse) -> CM ChatResponse
withUser' action =
  asks currentUser
    >>= readTVarIO
    >>= maybe (throwChatError CENoActiveUser) action

withUser :: (User -> CM ChatResponse) -> CM ChatResponse
withUser action = withUser' $ \user ->
  ifM (lift chatStarted) (action user) (throwChatError CEChatNotStarted)

withUser_ :: CM ChatResponse -> CM ChatResponse
withUser_ = withUser . const

withUserId' :: UserId -> (User -> CM ChatResponse) -> CM ChatResponse
withUserId' userId action = withUser' $ \user -> do
  checkSameUser userId user
  action user

withUserId :: UserId -> (User -> CM ChatResponse) -> CM ChatResponse
withUserId userId action = withUser $ \user -> do
  checkSameUser userId user
  action user

checkSameUser :: UserId -> User -> CM ()
checkSameUser userId User {userId = activeUserId} = when (userId /= activeUserId) $ throwChatError (CEDifferentActiveUser userId activeUserId)

chatStarted :: CM' Bool
chatStarted = fmap isJust . readTVarIO =<< asks agentAsync

waitChatStartedAndActivated :: CM' ()
waitChatStartedAndActivated = do
  agentStarted <- asks agentAsync
  chatActivated <- asks chatActivated
  atomically $ do
    started <- readTVar agentStarted
    activated <- readTVar chatActivated
    unless (isJust started && activated) retry

chatStoreCxt :: CM StoreCxt
chatStoreCxt = lift chatStoreCxt'
{-# INLINE chatStoreCxt #-}

chatStoreCxt' :: CM' StoreCxt
chatStoreCxt' = mkStoreCxt <$> asks config
{-# INLINE chatStoreCxt' #-}

chatVersionRange :: CM VersionRangeChat
chatVersionRange = lift chatVersionRange'
{-# INLINE chatVersionRange #-}

chatVersionRange' :: CM' VersionRangeChat
chatVersionRange' = do
  ChatConfig {chatVRange} <- asks config
  pure chatVRange
{-# INLINE chatVersionRange' #-}

adminContactReq :: ConnReqContact
adminContactReq =
  either error id $ strDecode "popopx:/contact#/?v=1&smp=smp%3A%2F%2FPQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo%3D%40smp6.popopx.im%2FK1rslx-m5bpXVIdMZg9NLUZ_8JBm8xTt%23MCowBQYDK2VuAyEALDeVe-sG8mRY22LsXlPgiwTNs9dbiLrNuA7f3ZMAJ2w%3D"

contactCReqHash :: ConnReqContact -> ConnReqUriHash
contactCReqHash = ConnReqUriHash . C.sha256Hash . strEncode

popopxChatImage :: ImageData
popopxChatImage = ImageData "data:image/png;base64,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"

popopxTeamContactProfile :: Profile
popopxTeamContactProfile =
  Profile
    { displayName = "Ask POPOPX Team",
      fullName = "",
      shortDescr = Just "Send questions about POPOPX app and your suggestions",
      description = Nothing,
      image = Just popopxChatImage,
      contactLink = Just $ CLFull adminContactReq,
      peerType = Nothing,
      preferences = Nothing,
      badge = Nothing,
      contactDomain = Nothing
    }

timeItToView :: String -> CM' a -> CM' a
timeItToView s action = do
  t1 <- liftIO getCurrentTime
  a <- action
  t2 <- liftIO getCurrentTime
  let diff = diffToMilliseconds $ diffUTCTime t2 t1
  toView' $ CEvtTimedAction s diff
  pure a

epochStart :: UTCTime
epochStart = UTCTime (fromGregorian 1970 1 1) (secondsToDiffTime 0)

drgRandomBytes :: Int -> CM ByteString
drgRandomBytes n = asks random >>= atomically . C.randomBytes n
