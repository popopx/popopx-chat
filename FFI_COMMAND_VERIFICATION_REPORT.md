# FFI Command Format Verification Report

Generated: 2026-10-30 10:24:53

## Summary

- Total commands: 395
- ✅ Match: 0
- ⚠️ Warning: 0
- ❌ Fail: 395

## ❌ Failed Commands (CRITICAL)

### showActiveUser
**Location**: Swift:L217
**Swift**: `/u`
**Haskell**: `NOT FOUND`

### listUsers
**Location**: Swift:L221
**Swift**: `/users`
**Haskell**: `NOT FOUND`

### apiSetActiveUser
**Location**: Swift:L222
**Swift**: `/_user \(userId)\(maybePwd(viewPwd))`
**Haskell**: `NOT FOUND`

### setAllContactReceipts
**Location**: Swift:L223
**Swift**: `/set receipts all \(onOff(enable))`
**Haskell**: `NOT FOUND`

### apiHideUser
**Location**: Swift:L238
**Swift**: `/_hide user \(userId) \(encodeJSON(viewPwd))`
**Haskell**: `NOT FOUND`

### apiUnhideUser
**Location**: Swift:L239
**Swift**: `/_unhide user \(userId) \(encodeJSON(viewPwd))`
**Haskell**: `NOT FOUND`

### apiMuteUser
**Location**: Swift:L240
**Swift**: `/_mute user \(userId)`
**Haskell**: `NOT FOUND`

### apiUnmuteUser
**Location**: Swift:L241
**Swift**: `/_unmute user \(userId)`
**Haskell**: `NOT FOUND`

### apiDeleteUser
**Location**: Swift:L242
**Swift**: `/_delete user \(userId) del_smp=\(onOff(delSMPQueues))\(maybePwd(viewPwd))`
**Haskell**: `NOT FOUND`

### startChat
**Location**: Swift:L243
**Swift**: `/_start main=\(onOff(mainApp)) snd_files=\(onOff(enableSndFiles))`
**Haskell**: `NOT FOUND`

### checkChatRunning
**Location**: Swift:L244
**Swift**: `/_check running`
**Haskell**: `NOT FOUND`

### apiStopChat
**Location**: Swift:L245
**Swift**: `/_stop`
**Haskell**: `NOT FOUND`

### apiActivateChat
**Location**: Swift:L246
**Swift**: `/_app activate restore=\(onOff(restore))`
**Haskell**: `NOT FOUND`

### apiSuspendChat
**Location**: Swift:L247
**Swift**: `/_app suspend \(timeoutMicroseconds)`
**Haskell**: `NOT FOUND`

### apiSetAppFilePaths
**Location**: Swift:L248
**Swift**: `/set file paths \(encodeJSON(AppFilePaths(appFilesFolder: filesFolder, appTempFolder: tempFolder, appAssetsFolder: assetsFolder)))`
**Haskell**: `NOT FOUND`

### apiSetEncryptLocalFiles
**Location**: Swift:L249
**Swift**: `/_files_encrypt \(onOff(enable))`
**Haskell**: `NOT FOUND`

### apiExportArchive
**Location**: Swift:L250
**Swift**: `/_db export \(encodeJSON(cfg))`
**Haskell**: `NOT FOUND`

### apiImportArchive
**Location**: Swift:L251
**Swift**: `/_db import \(encodeJSON(cfg))`
**Haskell**: `NOT FOUND`

### apiDeleteStorage
**Location**: Swift:L252
**Swift**: `/_db delete`
**Haskell**: `NOT FOUND`

### apiStorageEncryption
**Location**: Swift:L253
**Swift**: `/_db encryption \(encodeJSON(cfg))`
**Haskell**: `NOT FOUND`

### testStorageEncryption
**Location**: Swift:L254
**Swift**: `/db test key \(key)`
**Haskell**: `NOT FOUND`

### apiSaveSettings
**Location**: Swift:L255
**Swift**: `/_save app settings \(encodeJSON(settings))`
**Haskell**: `NOT FOUND`

### apiGetSettings
**Location**: Swift:L256
**Swift**: `/_get app settings \(encodeJSON(settings))`
**Haskell**: `NOT FOUND`

### apiGetChatTags
**Location**: Swift:L257
**Swift**: `/_get tags \(userId)`
**Haskell**: `NOT FOUND`

### apiGetChats
**Location**: Swift:L258
**Swift**: `/_get chats \(userId) pcc=on`
**Haskell**: `NOT FOUND`

### apiGetChatContentTypes
**Location**: Swift:L262
**Swift**: `/_get content types \(chatId)\(scopeRef(scope))`
**Haskell**: `NOT FOUND`

### apiGetChatItemInfo
**Location**: Swift:L263
**Swift**: `/_get item info \(ref(type, id, scope: scope)) \(itemId)`
**Haskell**: `NOT FOUND`

### apiCreateChatTag
**Location**: Swift:L269
**Swift**: `/_create tag \(encodeJSON(tag))`
**Haskell**: `NOT FOUND`

### apiSetChatTags
**Location**: Swift:L270
**Swift**: `/_tags \(ref(type, id, scope: nil)) \(tagIds.map({ `
**Haskell**: `NOT FOUND`

### apiDeleteChatTag
**Location**: Swift:L271
**Swift**: `/_delete tag \(tagId)`
**Haskell**: `NOT FOUND`

### apiUpdateChatTag
**Location**: Swift:L272
**Swift**: `/_update tag \(tagId) \(encodeJSON(tagData))`
**Haskell**: `NOT FOUND`

### apiReorderChatTags
**Location**: Swift:L273
**Swift**: `/_reorder tags \(tagIds.map({ `
**Haskell**: `NOT FOUND`

### apiUpdateChatItem
**Location**: Swift:L280
**Swift**: `/_update item \(ref(type, id, scope: scope)) \(itemId) live=\(onOff(live)) \(um.cmdString)`
**Haskell**: `NOT FOUND`

### apiDeleteChatItem
**Location**: Swift:L281
**Swift**: `/_delete item \(ref(type, id, scope: scope)) \(itemIds.map({ `
**Haskell**: `NOT FOUND`

### apiDeleteMemberChatItem
**Location**: Swift:L282
**Swift**: `/_delete member item #\(groupId) \(itemIds.map({ `
**Haskell**: `NOT FOUND`

### apiArchiveReceivedReports
**Location**: Swift:L283
**Swift**: `/_archive reports #\(groupId)`
**Haskell**: `NOT FOUND`

### apiDeleteReceivedReports
**Location**: Swift:L284
**Swift**: `/_delete reports #\(groupId) \(itemIds.map({ `
**Haskell**: `NOT FOUND`

### apiChatItemReaction
**Location**: Swift:L285
**Swift**: `/_reaction \(ref(type, id, scope: scope)) \(itemId) \(onOff(add)) \(encodeJSON(reaction))`
**Haskell**: `NOT FOUND`

### apiGetReactionMembers
**Location**: Swift:L286
**Swift**: `/_reaction members \(userId) #\(groupId) \(itemId) \(encodeJSON(reaction))`
**Haskell**: `NOT FOUND`

### apiPlanForwardChatItems
**Location**: Swift:L287
**Swift**: `/_forward plan \(ref(type, id, scope: scope)) \(itemIds.map({ `
**Haskell**: `NOT FOUND`

### apiGetNtfToken
**Location**: Swift:L295
**Swift**: `/_ntf get `
**Haskell**: `NOT FOUND`

### apiRegisterToken
**Location**: Swift:L296
**Swift**: `/_ntf register \(token.cmdString) \(notificationMode.rawValue)`
**Haskell**: `NOT FOUND`

### apiVerifyToken
**Location**: Swift:L297
**Swift**: `/_ntf verify \(token.cmdString) \(nonce) \(code)`
**Haskell**: `NOT FOUND`

### apiCheckToken
**Location**: Swift:L298
**Swift**: `/_ntf check \(token.cmdString)`
**Haskell**: `NOT FOUND`

### apiDeleteToken
**Location**: Swift:L299
**Swift**: `/_ntf delete \(token.cmdString)`
**Haskell**: `NOT FOUND`

### apiGetNtfConns
**Location**: Swift:L300
**Swift**: `/_ntf conns \(nonce) \(encNtfInfo)`
**Haskell**: `NOT FOUND`

### apiGetConnNtfMessages
**Location**: Swift:L301
**Swift**: `/_ntf conn messages \(connMsgReqs.map { $0.cmdString }.joined(separator: `
**Haskell**: `NOT FOUND`

### apiNewGroup
**Location**: Swift:L302
**Swift**: `/_group \(userId) incognito=\(onOff(incognito)) \(encodeJSON(groupProfile))`
**Haskell**: `NOT FOUND`

### apiNewPublicGroup
**Location**: Swift:L303
**Swift**: `/_public group \(userId) incognito=\(onOff(incognito)) \(relayIds.map(String.init).joined(separator: `
**Haskell**: `NOT FOUND`

### apiGetGroupRelays
**Location**: Swift:L304
**Swift**: `/_get relays #\(groupId)`
**Haskell**: `NOT FOUND`

### apiAddGroupRelays
**Location**: Swift:L305
**Swift**: `/_add relays #\(groupId) \(relayIds.map(String.init).joined(separator: `
**Haskell**: `NOT FOUND`

### apiAddMember
**Location**: Swift:L306
**Swift**: `/_add #\(groupId) \(contactId) \(memberRole)`
**Haskell**: `NOT FOUND`

### apiJoinGroup
**Location**: Swift:L307
**Swift**: `/_join #\(groupId)`
**Haskell**: `NOT FOUND`

### apiAcceptMember
**Location**: Swift:L308
**Swift**: `/_accept member #\(groupId) \(groupMemberId) \(memberRole.rawValue)`
**Haskell**: `NOT FOUND`

### apiDeleteMemberSupportChat
**Location**: Swift:L309
**Swift**: `/_delete member chat #\(groupId) \(groupMemberId)`
**Haskell**: `NOT FOUND`

### apiMembersRole
**Location**: Swift:L310
**Swift**: `/_member role #\(groupId) \(memberIds.map({ `
**Haskell**: `NOT FOUND`

### apiBlockMembersForAll
**Location**: Swift:L311
**Swift**: `/_block #\(groupId) \(memberIds.map({ `
**Haskell**: `NOT FOUND`

### apiRemoveMembers
**Location**: Swift:L312
**Swift**: `/_remove #\(groupId) \(memberIds.map({ `
**Haskell**: `NOT FOUND`

### apiLeaveGroup
**Location**: Swift:L313
**Swift**: `/_leave #\(groupId)`
**Haskell**: `NOT FOUND`

### apiListMembers
**Location**: Swift:L314
**Swift**: `/_members #\(groupId)`
**Haskell**: `NOT FOUND`

### apiUpdateGroupProfile
**Location**: Swift:L315
**Swift**: `/_group_profile #\(groupId) \(encodeJSON(groupProfile))`
**Haskell**: `NOT FOUND`

### apiCreateGroupLink
**Location**: Swift:L316
**Swift**: `/_create link #\(groupId) \(memberRole)`
**Haskell**: `NOT FOUND`

### apiGroupLinkMemberRole
**Location**: Swift:L317
**Swift**: `/_set link role #\(groupId) \(memberRole)`
**Haskell**: `NOT FOUND`

### apiDeleteGroupLink
**Location**: Swift:L318
**Swift**: `/_delete link #\(groupId)`
**Haskell**: `NOT FOUND`

### apiGetGroupLink
**Location**: Swift:L319
**Swift**: `/_get link #\(groupId)`
**Haskell**: `NOT FOUND`

### apiAddGroupShortLink
**Location**: Swift:L320
**Swift**: `/_short link #\(groupId)`
**Haskell**: `NOT FOUND`

### apiCreateMemberContact
**Location**: Swift:L321
**Swift**: `/_create member contact #\(groupId) \(groupMemberId)`
**Haskell**: `NOT FOUND`

### apiSendMemberContactInvitation
**Location**: Swift:L322
**Swift**: `/_invite member contact @\(contactId) \(mc.cmdString)`
**Haskell**: `NOT FOUND`

### apiAcceptMemberContact
**Location**: Swift:L323
**Swift**: `/_accept member contact @\(contactId)`
**Haskell**: `NOT FOUND`

### apiTestProtoServer
**Location**: Swift:L324
**Swift**: `/_server test \(userId) \(server)`
**Haskell**: `NOT FOUND`

### apiTestChatRelay
**Location**: Swift:L325
**Swift**: `/_relay test \(userId) \(address)`
**Haskell**: `NOT FOUND`

### apiGetServerOperators
**Location**: Swift:L326
**Swift**: `/_operators`
**Haskell**: `NOT FOUND`

### apiSetServerOperators
**Location**: Swift:L327
**Swift**: `/_operators \(encodeJSON(operators))`
**Haskell**: `NOT FOUND`

### apiGetUserServers
**Location**: Swift:L328
**Swift**: `/_servers \(userId)`
**Haskell**: `NOT FOUND`

### apiSetUserServers
**Location**: Swift:L329
**Swift**: `/_servers \(userId) \(encodeJSON(userServers))`
**Haskell**: `NOT FOUND`

### apiValidateServers
**Location**: Swift:L330
**Swift**: `/_validate_servers \(userId) \(encodeJSON(userServers))`
**Haskell**: `NOT FOUND`

### apiGetBinThereBots
**Location**: Swift:L331
**Swift**: `/_binthere_bots \(userId) \(botType)`
**Haskell**: `NOT FOUND`

### apiInsertBinThereBot
**Location**: Swift:L332
**Swift**: `/_binthere_bot_add \(userId) \(address) \(name ?? `
**Haskell**: `NOT FOUND`

### apiReportBinThereBotUse
**Location**: Swift:L333
**Swift**: `/_binthere_bot_use \(userId) \(botId)`
**Haskell**: `NOT FOUND`

### apiSyncBotDirectory
**Location**: Swift:L334
**Swift**: `/_bot_directory_sync \(userId) \(json)`
**Haskell**: `NOT FOUND`

### apiGetComputeBalance
**Location**: Swift:L335
**Swift**: `/_compute_balance \(userId)`
**Haskell**: `NOT FOUND`

### apiRecordComputePurchase
**Location**: Swift:L336
**Swift**: `/_compute_purchase_record \(userId) \(encodeJSON(purchase))`
**Haskell**: `NOT FOUND`

### apiGetComputePurchases
**Location**: Swift:L337
**Swift**: `/_compute_purchases \(userId)`
**Haskell**: `NOT FOUND`

### apiGetUsageConditions
**Location**: Swift:L338
**Swift**: `/_conditions`
**Haskell**: `NOT FOUND`

### apiSetConditionsNotified
**Location**: Swift:L339
**Swift**: `/_conditions_notified \(conditionsId)`
**Haskell**: `NOT FOUND`

### apiAcceptConditions
**Location**: Swift:L340
**Swift**: `/_accept_conditions \(conditionsId) \(joinedIds(operatorIds))`
**Haskell**: `NOT FOUND`

### apiSetChatItemTTL
**Location**: Swift:L341
**Swift**: `/_ttl \(userId) \(chatItemTTLStr(seconds: seconds))`
**Haskell**: `NOT FOUND`

### apiGetChatItemTTL
**Location**: Swift:L342
**Swift**: `/_ttl \(userId)`
**Haskell**: `NOT FOUND`

### apiSetChatTTL
**Location**: Swift:L343
**Swift**: `/_ttl \(userId) \(ref(type, id, scope: nil)) \(chatItemTTLStr(seconds: seconds))`
**Haskell**: `NOT FOUND`

### apiSetNetworkConfig
**Location**: Swift:L344
**Swift**: `/_network \(encodeJSON(networkConfig))`
**Haskell**: `NOT FOUND`

### apiGetNetworkConfig
**Location**: Swift:L345
**Swift**: `/network`
**Haskell**: `NOT FOUND`

### apiSetNetworkInfo
**Location**: Swift:L346
**Swift**: `/_network info \(encodeJSON(networkInfo))`
**Haskell**: `NOT FOUND`

### reconnectAllServers
**Location**: Swift:L347
**Swift**: `/reconnect`
**Haskell**: `NOT FOUND`

### reconnectServer
**Location**: Swift:L348
**Swift**: `/reconnect \(userId) \(smpServer)`
**Haskell**: `NOT FOUND`

### apiSetChatSettings
**Location**: Swift:L349
**Swift**: `/_settings \(ref(type, id, scope: nil)) \(encodeJSON(chatSettings))`
**Haskell**: `NOT FOUND`

### apiSetMemberSettings
**Location**: Swift:L350
**Swift**: `/_member settings #\(groupId) \(groupMemberId) \(encodeJSON(memberSettings))`
**Haskell**: `NOT FOUND`

### apiGetUpdatedGroupLinkData
**Location**: Swift:L351
**Swift**: `/_get group link data #\(groupId)`
**Haskell**: `NOT FOUND`

### apiContactInfo
**Location**: Swift:L352
**Swift**: `/_info @\(contactId)`
**Haskell**: `NOT FOUND`

### apiGroupMemberInfo
**Location**: Swift:L353
**Swift**: `/_info #\(groupId) \(groupMemberId)`
**Haskell**: `NOT FOUND`

### apiContactQueueInfo
**Location**: Swift:L354
**Swift**: `/_queue info @\(contactId)`
**Haskell**: `NOT FOUND`

### apiGroupMemberQueueInfo
**Location**: Swift:L355
**Swift**: `/_queue info #\(groupId) \(groupMemberId)`
**Haskell**: `NOT FOUND`

### apiSwitchContact
**Location**: Swift:L356
**Swift**: `/_switch @\(contactId)`
**Haskell**: `NOT FOUND`

### apiSwitchGroupMember
**Location**: Swift:L357
**Swift**: `/_switch #\(groupId) \(groupMemberId)`
**Haskell**: `NOT FOUND`

### apiAbortSwitchContact
**Location**: Swift:L358
**Swift**: `/_abort switch @\(contactId)`
**Haskell**: `NOT FOUND`

### apiAbortSwitchGroupMember
**Location**: Swift:L359
**Swift**: `/_abort switch #\(groupId) \(groupMemberId)`
**Haskell**: `NOT FOUND`

### apiGetContactCode
**Location**: Swift:L370
**Swift**: `/_get code @\(contactId)`
**Haskell**: `NOT FOUND`

### apiGetGroupMemberCode
**Location**: Swift:L371
**Swift**: `/_get code #\(groupId) \(groupMemberId)`
**Haskell**: `NOT FOUND`

### apiVerifyContact
**Location**: Swift:L372
**Swift**: `/_verify code @\(contactId) \(connectionCode)`
**Haskell**: `NOT FOUND`

### apiVerifyContact
**Location**: Swift:L373
**Swift**: `/_verify code @\(contactId)`
**Haskell**: `NOT FOUND`

### apiVerifyGroupMember
**Location**: Swift:L374
**Swift**: `/_verify code #\(groupId) \(groupMemberId) \(connectionCode)`
**Haskell**: `NOT FOUND`

### apiVerifyGroupMember
**Location**: Swift:L375
**Swift**: `/_verify code #\(groupId) \(groupMemberId)`
**Haskell**: `NOT FOUND`

### apiAddContact
**Location**: Swift:L376
**Swift**: `/_connect \(userId) incognito=\(onOff(incognito))`
**Haskell**: `NOT FOUND`

### apiSetConnectionIncognito
**Location**: Swift:L377
**Swift**: `/_set incognito :\(connId) \(onOff(incognito))`
**Haskell**: `NOT FOUND`

### apiChangeConnectionUser
**Location**: Swift:L378
**Swift**: `/_set conn user :\(connId) \(userId)`
**Haskell**: `NOT FOUND`

### apiPrepareContact
**Location**: Swift:L382
**Swift**: `/_prepare contact \(userId) \(connLink.connFullLink) \(connLink.connShortLink ?? `
**Haskell**: `NOT FOUND`

### apiPrepareGroup
**Location**: Swift:L383
**Swift**: `/_prepare group \(userId) \(connLink.connFullLink) \(connLink.connShortLink ?? `
**Haskell**: `NOT FOUND`

### apiChangePreparedContactUser
**Location**: Swift:L384
**Swift**: `/_set contact user @\(contactId) \(newUserId)`
**Haskell**: `NOT FOUND`

### apiChangePreparedGroupUser
**Location**: Swift:L385
**Swift**: `/_set group user #\(groupId) \(newUserId)`
**Haskell**: `NOT FOUND`

### apiConnectPreparedContact
**Location**: Swift:L386
**Swift**: `/_connect contact @\(contactId) incognito=\(onOff(incognito))\(maybeContent(mc))`
**Haskell**: `NOT FOUND`

### apiConnectPreparedGroup
**Location**: Swift:L387
**Swift**: `/_connect group #\(groupId) incognito=\(onOff(incognito))\(maybeContent(mc))`
**Haskell**: `NOT FOUND`

### apiConnect
**Location**: Swift:L388
**Swift**: `/_connect \(userId) incognito=\(onOff(incognito)) \(connLink.connFullLink) \(connLink.connShortLink ?? `
**Haskell**: `NOT FOUND`

### apiConnectContactViaAddress
**Location**: Swift:L389
**Swift**: `/_connect contact \(userId) incognito=\(onOff(incognito)) \(contactId)`
**Haskell**: `NOT FOUND`

### apiDeleteChat
**Location**: Swift:L390
**Swift**: `/_delete \(ref(type, id, scope: nil)) \(chatDeleteMode.cmdString)`
**Haskell**: `NOT FOUND`

### apiClearChat
**Location**: Swift:L391
**Swift**: `/_clear chat \(ref(type, id, scope: nil))`
**Haskell**: `NOT FOUND`

### apiListContacts
**Location**: Swift:L392
**Swift**: `/_contacts \(userId)`
**Haskell**: `NOT FOUND`

### apiUpdateProfile
**Location**: Swift:L393
**Swift**: `/_profile \(userId) \(encodeJSON(profile))`
**Haskell**: `NOT FOUND`

### apiSetContactPrefs
**Location**: Swift:L394
**Swift**: `/_set prefs @\(contactId) \(encodeJSON(preferences))`
**Haskell**: `NOT FOUND`

### apiSetContactAlias
**Location**: Swift:L395
**Swift**: `/_set alias @\(contactId) \(sanitizeFFIParam(localAlias, maxLen: 256))`
**Haskell**: `NOT FOUND`

### apiSetGroupAlias
**Location**: Swift:L396
**Swift**: `/_set alias #\(groupId) \(sanitizeFFIParam(localAlias, maxLen: 256))`
**Haskell**: `NOT FOUND`

### apiSetConnectionAlias
**Location**: Swift:L397
**Swift**: `/_set alias :\(connId) \(sanitizeFFIParam(localAlias, maxLen: 256))`
**Haskell**: `NOT FOUND`

### apiSetUserUIThemes
**Location**: Swift:L398
**Swift**: `/_set theme user \(userId) \(themes != nil ? encodeJSON(themes) : `
**Haskell**: `NOT FOUND`

### apiSetChatUIThemes
**Location**: Swift:L399
**Swift**: `/_set theme \(chatId) \(themes != nil ? encodeJSON(themes) : `
**Haskell**: `NOT FOUND`

### apiCreateMyAddress
**Location**: Swift:L400
**Swift**: `/_address \(userId)`
**Haskell**: `NOT FOUND`

### apiDeleteMyAddress
**Location**: Swift:L401
**Swift**: `/_delete_address \(userId)`
**Haskell**: `NOT FOUND`

### apiShowMyAddress
**Location**: Swift:L402
**Swift**: `/_show_address \(userId)`
**Haskell**: `NOT FOUND`

### apiAddMyAddressShortLink
**Location**: Swift:L403
**Swift**: `/_short_link_address \(userId)`
**Haskell**: `NOT FOUND`

### apiSetProfileAddress
**Location**: Swift:L404
**Swift**: `/_profile_address \(userId) \(onOff(on))`
**Haskell**: `NOT FOUND`

### apiSetAddressSettings
**Location**: Swift:L405
**Swift**: `/_address_settings \(userId) \(encodeJSON(addressSettings))`
**Haskell**: `NOT FOUND`

### apiAcceptContact
**Location**: Swift:L406
**Swift**: `/_accept incognito=\(onOff(incognito)) \(contactReqId)`
**Haskell**: `NOT FOUND`

### apiRejectContact
**Location**: Swift:L407
**Swift**: `/_reject \(contactReqId)`
**Haskell**: `NOT FOUND`

### apiSendCallInvitation
**Location**: Swift:L408
**Swift**: `/_call invite @\(contact.apiId) \(encodeJSON(callType))`
**Haskell**: `NOT FOUND`

### apiRejectCall
**Location**: Swift:L409
**Swift**: `/_call reject @\(contact.apiId)`
**Haskell**: `NOT FOUND`

### apiSendCallOffer
**Location**: Swift:L410
**Swift**: `/_call offer @\(contact.apiId) \(encodeJSON(callOffer))`
**Haskell**: `NOT FOUND`

### apiSendCallAnswer
**Location**: Swift:L411
**Swift**: `/_call answer @\(contact.apiId) \(encodeJSON(answer))`
**Haskell**: `NOT FOUND`

### apiSendCallExtraInfo
**Location**: Swift:L412
**Swift**: `/_call extra @\(contact.apiId) \(encodeJSON(extraInfo))`
**Haskell**: `NOT FOUND`

### apiEndCall
**Location**: Swift:L413
**Swift**: `/_call end @\(contact.apiId)`
**Haskell**: `NOT FOUND`

### apiGetCallInvitations
**Location**: Swift:L414
**Swift**: `/_call get`
**Haskell**: `NOT FOUND`

### apiCallStatus
**Location**: Swift:L415
**Swift**: `/_call status @\(contact.apiId) \(callStatus.rawValue)`
**Haskell**: `NOT FOUND`

### apiChatRead
**Location**: Swift:L416
**Swift**: `/_read chat \(ref(type, id, scope: scope))`
**Haskell**: `NOT FOUND`

### apiChatItemsRead
**Location**: Swift:L417
**Swift**: `/_read chat items \(ref(type, id, scope: scope)) \(joinedIds(itemIds))`
**Haskell**: `NOT FOUND`

### apiChatUnread
**Location**: Swift:L418
**Swift**: `/_unread chat \(ref(type, id, scope: nil)) \(onOff(unreadChat))`
**Haskell**: `NOT FOUND`

### receiveFile
**Location**: Swift:L419
**Swift**: `/freceive \(fileId)\(onOffParam(`
**Haskell**: `NOT FOUND`

### setFileToReceive
**Location**: Swift:L420
**Swift**: `/_set_file_to_receive \(fileId)\(onOffParam(`
**Haskell**: `NOT FOUND`

### cancelFile
**Location**: Swift:L421
**Swift**: `/fcancel \(fileId)`
**Haskell**: `NOT FOUND`

### setLocalDeviceName
**Location**: Swift:L422
**Swift**: `/set device name \(displayName)`
**Haskell**: `NOT FOUND`

### connectRemoteCtrl
**Location**: Swift:L423
**Swift**: `/connect remote ctrl \(xrcpInv)`
**Haskell**: `NOT FOUND`

### confirmRemoteCtrl
**Location**: Swift:L424
**Swift**: `/confirm remote ctrl \(rcId)`
**Haskell**: `NOT FOUND`

### verifyRemoteCtrlSession
**Location**: Swift:L425
**Swift**: `/verify remote ctrl \(sessCode)`
**Haskell**: `NOT FOUND`

### listRemoteCtrls
**Location**: Swift:L426
**Swift**: `/list remote ctrls`
**Haskell**: `NOT FOUND`

### stopRemoteCtrl
**Location**: Swift:L427
**Swift**: `/stop remote ctrl`
**Haskell**: `NOT FOUND`

### deleteRemoteCtrl
**Location**: Swift:L428
**Swift**: `/delete remote ctrl \(rcId)`
**Haskell**: `NOT FOUND`

### apiUploadStandaloneFile
**Location**: Swift:L429
**Swift**: `/_upload \(userId) \(sanitizeFFIParam(file.filePath, maxLen: 4096))`
**Haskell**: `NOT FOUND`

### apiDownloadStandaloneFile
**Location**: Swift:L430
**Swift**: `/_download \(userId) \(sanitizeFFIParam(link, maxLen: 4096)) \(sanitizeFFIParam(file.filePath, maxLen: 4096))`
**Haskell**: `NOT FOUND`

### apiStandaloneFileInfo
**Location**: Swift:L431
**Swift**: `/_download info \(sanitizeFFIParam(link, maxLen: 4096))`
**Haskell**: `NOT FOUND`

### apiRedeemBadgeCode
**Location**: Swift:L432
**Swift**: `/_redeem_badge_code \(userId) \(code)`
**Haskell**: `NOT FOUND`

### apiGetBadgeState
**Location**: Swift:L433
**Swift**: `/_badge state \(userId)`
**Haskell**: `NOT FOUND`

### apiGetBadgeLedger
**Location**: Swift:L434
**Swift**: `/_badge ledger \(userId) \(badgePurchaseId)`
**Haskell**: `NOT FOUND`

### showVersion
**Location**: Swift:L437
**Swift**: `/version`
**Haskell**: `NOT FOUND`

### getAgentSubsTotal
**Location**: Swift:L438
**Swift**: `/get subs total \(userId)`
**Haskell**: `NOT FOUND`

### getAgentServersSummary
**Location**: Swift:L439
**Swift**: `/get servers summary \(userId)`
**Haskell**: `NOT FOUND`

### resetAgentServersStats
**Location**: Swift:L440
**Swift**: `/reset servers stats`
**Haskell**: `NOT FOUND`

### showActiveUser
**Location**: Swift:L449
**Swift**: `showActiveUser`
**Haskell**: `NOT FOUND`

### createActiveUser
**Location**: Swift:L450
**Swift**: `createActiveUser`
**Haskell**: `NOT FOUND`

### listUsers
**Location**: Swift:L451
**Swift**: `listUsers`
**Haskell**: `NOT FOUND`

### apiSetActiveUser
**Location**: Swift:L452
**Swift**: `apiSetActiveUser`
**Haskell**: `NOT FOUND`

### setAllContactReceipts
**Location**: Swift:L453
**Swift**: `setAllContactReceipts`
**Haskell**: `NOT FOUND`

### apiSetUserContactReceipts
**Location**: Swift:L454
**Swift**: `apiSetUserContactReceipts`
**Haskell**: `NOT FOUND`

### apiSetUserGroupReceipts
**Location**: Swift:L455
**Swift**: `apiSetUserGroupReceipts`
**Haskell**: `NOT FOUND`

### apiSetUserAutoAcceptMemberContacts
**Location**: Swift:L456
**Swift**: `apiSetUserAutoAcceptMemberContacts`
**Haskell**: `NOT FOUND`

### apiSetUserAutoAcceptGroupInvitations
**Location**: Swift:L457
**Swift**: `apiSetUserAutoAcceptGroupInvitations`
**Haskell**: `NOT FOUND`

### apiSetUserChatRelay
**Location**: Swift:L458
**Swift**: `apiSetUserChatRelay`
**Haskell**: `NOT FOUND`

### apiSetClientService
**Location**: Swift:L459
**Swift**: `apiSetClientService`
**Haskell**: `NOT FOUND`

### apiHideUser
**Location**: Swift:L460
**Swift**: `apiHideUser`
**Haskell**: `NOT FOUND`

### apiUnhideUser
**Location**: Swift:L461
**Swift**: `apiUnhideUser`
**Haskell**: `NOT FOUND`

### apiMuteUser
**Location**: Swift:L462
**Swift**: `apiMuteUser`
**Haskell**: `NOT FOUND`

### apiUnmuteUser
**Location**: Swift:L463
**Swift**: `apiUnmuteUser`
**Haskell**: `NOT FOUND`

### apiDeleteUser
**Location**: Swift:L464
**Swift**: `apiDeleteUser`
**Haskell**: `NOT FOUND`

### startChat
**Location**: Swift:L465
**Swift**: `startChat`
**Haskell**: `NOT FOUND`

### checkChatRunning
**Location**: Swift:L466
**Swift**: `checkChatRunning`
**Haskell**: `NOT FOUND`

### apiStopChat
**Location**: Swift:L467
**Swift**: `apiStopChat`
**Haskell**: `NOT FOUND`

### apiActivateChat
**Location**: Swift:L468
**Swift**: `apiActivateChat`
**Haskell**: `NOT FOUND`

### apiSuspendChat
**Location**: Swift:L469
**Swift**: `apiSuspendChat`
**Haskell**: `NOT FOUND`

### apiSetAppFilePaths
**Location**: Swift:L470
**Swift**: `apiSetAppFilePaths`
**Haskell**: `NOT FOUND`

### apiSetEncryptLocalFiles
**Location**: Swift:L471
**Swift**: `apiSetEncryptLocalFiles`
**Haskell**: `NOT FOUND`

### apiExportArchive
**Location**: Swift:L472
**Swift**: `apiExportArchive`
**Haskell**: `NOT FOUND`

### apiImportArchive
**Location**: Swift:L473
**Swift**: `apiImportArchive`
**Haskell**: `NOT FOUND`

### apiDeleteStorage
**Location**: Swift:L474
**Swift**: `apiDeleteStorage`
**Haskell**: `NOT FOUND`

### apiStorageEncryption
**Location**: Swift:L475
**Swift**: `apiStorageEncryption`
**Haskell**: `NOT FOUND`

### testStorageEncryption
**Location**: Swift:L476
**Swift**: `testStorageEncryption`
**Haskell**: `NOT FOUND`

### apiSaveSettings
**Location**: Swift:L477
**Swift**: `apiSaveSettings`
**Haskell**: `NOT FOUND`

### apiGetSettings
**Location**: Swift:L478
**Swift**: `apiGetSettings`
**Haskell**: `NOT FOUND`

### apiGetChatTags
**Location**: Swift:L479
**Swift**: `apiGetChatTags`
**Haskell**: `NOT FOUND`

### apiGetChats
**Location**: Swift:L480
**Swift**: `apiGetChats`
**Haskell**: `NOT FOUND`

### apiGetChat
**Location**: Swift:L481
**Swift**: `apiGetChat`
**Haskell**: `NOT FOUND`

### apiGetChatContentTypes
**Location**: Swift:L482
**Swift**: `apiGetChatContentTypes`
**Haskell**: `NOT FOUND`

### apiGetChatItemInfo
**Location**: Swift:L483
**Swift**: `apiGetChatItemInfo`
**Haskell**: `NOT FOUND`

### apiSendMessages
**Location**: Swift:L484
**Swift**: `apiSendMessages`
**Haskell**: `NOT FOUND`

### apiCreateChatTag
**Location**: Swift:L485
**Swift**: `apiCreateChatTag`
**Haskell**: `NOT FOUND`

### apiSetChatTags
**Location**: Swift:L486
**Swift**: `apiSetChatTags`
**Haskell**: `NOT FOUND`

### apiDeleteChatTag
**Location**: Swift:L487
**Swift**: `apiDeleteChatTag`
**Haskell**: `NOT FOUND`

### apiUpdateChatTag
**Location**: Swift:L488
**Swift**: `apiUpdateChatTag`
**Haskell**: `NOT FOUND`

### apiReorderChatTags
**Location**: Swift:L489
**Swift**: `apiReorderChatTags`
**Haskell**: `NOT FOUND`

### apiCreateChatItems
**Location**: Swift:L490
**Swift**: `apiCreateChatItems`
**Haskell**: `NOT FOUND`

### apiReportMessage
**Location**: Swift:L491
**Swift**: `apiReportMessage`
**Haskell**: `NOT FOUND`

### apiUpdateChatItem
**Location**: Swift:L492
**Swift**: `apiUpdateChatItem`
**Haskell**: `NOT FOUND`

### apiDeleteChatItem
**Location**: Swift:L493
**Swift**: `apiDeleteChatItem`
**Haskell**: `NOT FOUND`

### apiConnectContactViaAddress
**Location**: Swift:L494
**Swift**: `apiConnectContactViaAddress`
**Haskell**: `NOT FOUND`

### apiDeleteMemberChatItem
**Location**: Swift:L495
**Swift**: `apiDeleteMemberChatItem`
**Haskell**: `NOT FOUND`

### apiArchiveReceivedReports
**Location**: Swift:L496
**Swift**: `apiArchiveReceivedReports`
**Haskell**: `NOT FOUND`

### apiDeleteReceivedReports
**Location**: Swift:L497
**Swift**: `apiDeleteReceivedReports`
**Haskell**: `NOT FOUND`

### apiChatItemReaction
**Location**: Swift:L498
**Swift**: `apiChatItemReaction`
**Haskell**: `NOT FOUND`

### apiGetReactionMembers
**Location**: Swift:L499
**Swift**: `apiGetReactionMembers`
**Haskell**: `NOT FOUND`

### apiPlanForwardChatItems
**Location**: Swift:L500
**Swift**: `apiPlanForwardChatItems`
**Haskell**: `NOT FOUND`

### apiForwardChatItems
**Location**: Swift:L501
**Swift**: `apiForwardChatItems`
**Haskell**: `NOT FOUND`

### apiShareChatMsgContent
**Location**: Swift:L502
**Swift**: `apiShareChatMsgContent`
**Haskell**: `NOT FOUND`

### apiGetNtfToken
**Location**: Swift:L503
**Swift**: `apiGetNtfToken`
**Haskell**: `NOT FOUND`

### apiRegisterToken
**Location**: Swift:L504
**Swift**: `apiRegisterToken`
**Haskell**: `NOT FOUND`

### apiVerifyToken
**Location**: Swift:L505
**Swift**: `apiVerifyToken`
**Haskell**: `NOT FOUND`

### apiCheckToken
**Location**: Swift:L506
**Swift**: `apiCheckToken`
**Haskell**: `NOT FOUND`

### apiDeleteToken
**Location**: Swift:L507
**Swift**: `apiDeleteToken`
**Haskell**: `NOT FOUND`

### apiGetNtfConns
**Location**: Swift:L508
**Swift**: `apiGetNtfConns`
**Haskell**: `NOT FOUND`

### apiGetConnNtfMessages
**Location**: Swift:L509
**Swift**: `apiGetConnNtfMessages`
**Haskell**: `NOT FOUND`

### apiNewGroup
**Location**: Swift:L510
**Swift**: `apiNewGroup`
**Haskell**: `NOT FOUND`

### apiNewPublicGroup
**Location**: Swift:L511
**Swift**: `apiNewPublicGroup`
**Haskell**: `NOT FOUND`

### apiGetGroupRelays
**Location**: Swift:L512
**Swift**: `apiGetGroupRelays`
**Haskell**: `NOT FOUND`

### apiAddGroupRelays
**Location**: Swift:L513
**Swift**: `apiAddGroupRelays`
**Haskell**: `NOT FOUND`

### apiAddMember
**Location**: Swift:L514
**Swift**: `apiAddMember`
**Haskell**: `NOT FOUND`

### apiJoinGroup
**Location**: Swift:L515
**Swift**: `apiJoinGroup`
**Haskell**: `NOT FOUND`

### apiAcceptMember
**Location**: Swift:L516
**Swift**: `apiAcceptMember`
**Haskell**: `NOT FOUND`

### apiDeleteMemberSupportChat
**Location**: Swift:L517
**Swift**: `apiDeleteMemberSupportChat`
**Haskell**: `NOT FOUND`

### apiMembersRole
**Location**: Swift:L518
**Swift**: `apiMembersRole`
**Haskell**: `NOT FOUND`

### apiBlockMembersForAll
**Location**: Swift:L519
**Swift**: `apiBlockMembersForAll`
**Haskell**: `NOT FOUND`

### apiRemoveMembers
**Location**: Swift:L520
**Swift**: `apiRemoveMembers`
**Haskell**: `NOT FOUND`

### apiLeaveGroup
**Location**: Swift:L521
**Swift**: `apiLeaveGroup`
**Haskell**: `NOT FOUND`

### apiListMembers
**Location**: Swift:L522
**Swift**: `apiListMembers`
**Haskell**: `NOT FOUND`

### apiUpdateGroupProfile
**Location**: Swift:L523
**Swift**: `apiUpdateGroupProfile`
**Haskell**: `NOT FOUND`

### apiCreateGroupLink
**Location**: Swift:L524
**Swift**: `apiCreateGroupLink`
**Haskell**: `NOT FOUND`

### apiGroupLinkMemberRole
**Location**: Swift:L525
**Swift**: `apiGroupLinkMemberRole`
**Haskell**: `NOT FOUND`

### apiDeleteGroupLink
**Location**: Swift:L526
**Swift**: `apiDeleteGroupLink`
**Haskell**: `NOT FOUND`

### apiGetGroupLink
**Location**: Swift:L527
**Swift**: `apiGetGroupLink`
**Haskell**: `NOT FOUND`

### apiAddGroupShortLink
**Location**: Swift:L528
**Swift**: `apiAddGroupShortLink`
**Haskell**: `NOT FOUND`

### apiCreateMemberContact
**Location**: Swift:L529
**Swift**: `apiCreateMemberContact`
**Haskell**: `NOT FOUND`

### apiSendMemberContactInvitation
**Location**: Swift:L530
**Swift**: `apiSendMemberContactInvitation`
**Haskell**: `NOT FOUND`

### apiAcceptMemberContact
**Location**: Swift:L531
**Swift**: `apiAcceptMemberContact`
**Haskell**: `NOT FOUND`

### apiTestProtoServer
**Location**: Swift:L532
**Swift**: `apiTestProtoServer`
**Haskell**: `NOT FOUND`

### apiTestChatRelay
**Location**: Swift:L533
**Swift**: `apiTestChatRelay`
**Haskell**: `NOT FOUND`

### apiGetServerOperators
**Location**: Swift:L534
**Swift**: `apiGetServerOperators`
**Haskell**: `NOT FOUND`

### apiSetServerOperators
**Location**: Swift:L535
**Swift**: `apiSetServerOperators`
**Haskell**: `NOT FOUND`

### apiGetUserServers
**Location**: Swift:L536
**Swift**: `apiGetUserServers`
**Haskell**: `NOT FOUND`

### apiSetUserServers
**Location**: Swift:L537
**Swift**: `apiSetUserServers`
**Haskell**: `NOT FOUND`

### apiValidateServers
**Location**: Swift:L538
**Swift**: `apiValidateServers`
**Haskell**: `NOT FOUND`

### apiGetUsageConditions
**Location**: Swift:L539
**Swift**: `apiGetUsageConditions`
**Haskell**: `NOT FOUND`

### apiSetConditionsNotified
**Location**: Swift:L540
**Swift**: `apiSetConditionsNotified`
**Haskell**: `NOT FOUND`

### apiAcceptConditions
**Location**: Swift:L541
**Swift**: `apiAcceptConditions`
**Haskell**: `NOT FOUND`

### apiSetChatItemTTL
**Location**: Swift:L542
**Swift**: `apiSetChatItemTTL`
**Haskell**: `NOT FOUND`

### apiGetChatItemTTL
**Location**: Swift:L543
**Swift**: `apiGetChatItemTTL`
**Haskell**: `NOT FOUND`

### apiSetChatTTL
**Location**: Swift:L544
**Swift**: `apiSetChatTTL`
**Haskell**: `NOT FOUND`

### apiSetNetworkConfig
**Location**: Swift:L545
**Swift**: `apiSetNetworkConfig`
**Haskell**: `NOT FOUND`

### apiGetNetworkConfig
**Location**: Swift:L546
**Swift**: `apiGetNetworkConfig`
**Haskell**: `NOT FOUND`

### apiSetNetworkInfo
**Location**: Swift:L547
**Swift**: `apiSetNetworkInfo`
**Haskell**: `NOT FOUND`

### reconnectAllServers
**Location**: Swift:L548
**Swift**: `reconnectAllServers`
**Haskell**: `NOT FOUND`

### reconnectServer
**Location**: Swift:L549
**Swift**: `reconnectServer`
**Haskell**: `NOT FOUND`

### apiSetChatSettings
**Location**: Swift:L550
**Swift**: `apiSetChatSettings`
**Haskell**: `NOT FOUND`

### apiSetMemberSettings
**Location**: Swift:L551
**Swift**: `apiSetMemberSettings`
**Haskell**: `NOT FOUND`

### apiGetUpdatedGroupLinkData
**Location**: Swift:L552
**Swift**: `apiGetUpdatedGroupLinkData`
**Haskell**: `NOT FOUND`

### apiContactInfo
**Location**: Swift:L553
**Swift**: `apiContactInfo`
**Haskell**: `NOT FOUND`

### apiGroupMemberInfo
**Location**: Swift:L554
**Swift**: `apiGroupMemberInfo`
**Haskell**: `NOT FOUND`

### apiContactQueueInfo
**Location**: Swift:L555
**Swift**: `apiContactQueueInfo`
**Haskell**: `NOT FOUND`

### apiGroupMemberQueueInfo
**Location**: Swift:L556
**Swift**: `apiGroupMemberQueueInfo`
**Haskell**: `NOT FOUND`

### apiSwitchContact
**Location**: Swift:L557
**Swift**: `apiSwitchContact`
**Haskell**: `NOT FOUND`

### apiSwitchGroupMember
**Location**: Swift:L558
**Swift**: `apiSwitchGroupMember`
**Haskell**: `NOT FOUND`

### apiAbortSwitchContact
**Location**: Swift:L559
**Swift**: `apiAbortSwitchContact`
**Haskell**: `NOT FOUND`

### apiAbortSwitchGroupMember
**Location**: Swift:L560
**Swift**: `apiAbortSwitchGroupMember`
**Haskell**: `NOT FOUND`

### apiSyncContactRatchet
**Location**: Swift:L561
**Swift**: `apiSyncContactRatchet`
**Haskell**: `NOT FOUND`

### apiSyncGroupMemberRatchet
**Location**: Swift:L562
**Swift**: `apiSyncGroupMemberRatchet`
**Haskell**: `NOT FOUND`

### apiGetContactCode
**Location**: Swift:L563
**Swift**: `apiGetContactCode`
**Haskell**: `NOT FOUND`

### apiGetGroupMemberCode
**Location**: Swift:L564
**Swift**: `apiGetGroupMemberCode`
**Haskell**: `NOT FOUND`

### apiVerifyContact
**Location**: Swift:L565
**Swift**: `apiVerifyContact`
**Haskell**: `NOT FOUND`

### apiVerifyGroupMember
**Location**: Swift:L566
**Swift**: `apiVerifyGroupMember`
**Haskell**: `NOT FOUND`

### apiAddContact
**Location**: Swift:L567
**Swift**: `apiAddContact`
**Haskell**: `NOT FOUND`

### apiSetConnectionIncognito
**Location**: Swift:L568
**Swift**: `apiSetConnectionIncognito`
**Haskell**: `NOT FOUND`

### apiChangeConnectionUser
**Location**: Swift:L569
**Swift**: `apiChangeConnectionUser`
**Haskell**: `NOT FOUND`

### apiConnectPlan
**Location**: Swift:L570
**Swift**: `apiConnectPlan`
**Haskell**: `NOT FOUND`

### apiPrepareContact
**Location**: Swift:L571
**Swift**: `apiPrepareContact`
**Haskell**: `NOT FOUND`

### apiPrepareGroup
**Location**: Swift:L572
**Swift**: `apiPrepareGroup`
**Haskell**: `NOT FOUND`

### apiChangePreparedContactUser
**Location**: Swift:L573
**Swift**: `apiChangePreparedContactUser`
**Haskell**: `NOT FOUND`

### apiChangePreparedGroupUser
**Location**: Swift:L574
**Swift**: `apiChangePreparedGroupUser`
**Haskell**: `NOT FOUND`

### apiConnectPreparedContact
**Location**: Swift:L575
**Swift**: `apiConnectPreparedContact`
**Haskell**: `NOT FOUND`

### apiConnectPreparedGroup
**Location**: Swift:L576
**Swift**: `apiConnectPreparedGroup`
**Haskell**: `NOT FOUND`

### apiConnect
**Location**: Swift:L577
**Swift**: `apiConnect`
**Haskell**: `NOT FOUND`

### apiDeleteChat
**Location**: Swift:L578
**Swift**: `apiDeleteChat`
**Haskell**: `NOT FOUND`

### apiClearChat
**Location**: Swift:L579
**Swift**: `apiClearChat`
**Haskell**: `NOT FOUND`

### apiListContacts
**Location**: Swift:L580
**Swift**: `apiListContacts`
**Haskell**: `NOT FOUND`

### apiUpdateProfile
**Location**: Swift:L581
**Swift**: `apiUpdateProfile`
**Haskell**: `NOT FOUND`

### apiSetContactPrefs
**Location**: Swift:L582
**Swift**: `apiSetContactPrefs`
**Haskell**: `NOT FOUND`

### apiSetContactAlias
**Location**: Swift:L583
**Swift**: `apiSetContactAlias`
**Haskell**: `NOT FOUND`

### apiSetGroupAlias
**Location**: Swift:L584
**Swift**: `apiSetGroupAlias`
**Haskell**: `NOT FOUND`

### apiSetConnectionAlias
**Location**: Swift:L585
**Swift**: `apiSetConnectionAlias`
**Haskell**: `NOT FOUND`

### apiSetUserUIThemes
**Location**: Swift:L586
**Swift**: `apiSetUserUIThemes`
**Haskell**: `NOT FOUND`

### apiSetChatUIThemes
**Location**: Swift:L587
**Swift**: `apiSetChatUIThemes`
**Haskell**: `NOT FOUND`

### apiCreateMyAddress
**Location**: Swift:L588
**Swift**: `apiCreateMyAddress`
**Haskell**: `NOT FOUND`

### apiDeleteMyAddress
**Location**: Swift:L589
**Swift**: `apiDeleteMyAddress`
**Haskell**: `NOT FOUND`

### apiShowMyAddress
**Location**: Swift:L590
**Swift**: `apiShowMyAddress`
**Haskell**: `NOT FOUND`

### apiAddMyAddressShortLink
**Location**: Swift:L591
**Swift**: `apiAddMyAddressShortLink`
**Haskell**: `NOT FOUND`

### apiSetProfileAddress
**Location**: Swift:L592
**Swift**: `apiSetProfileAddress`
**Haskell**: `NOT FOUND`

### apiSetAddressSettings
**Location**: Swift:L593
**Swift**: `apiSetAddressSettings`
**Haskell**: `NOT FOUND`

### apiAcceptContact
**Location**: Swift:L594
**Swift**: `apiAcceptContact`
**Haskell**: `NOT FOUND`

### apiRejectContact
**Location**: Swift:L595
**Swift**: `apiRejectContact`
**Haskell**: `NOT FOUND`

### apiSendCallInvitation
**Location**: Swift:L596
**Swift**: `apiSendCallInvitation`
**Haskell**: `NOT FOUND`

### apiRejectCall
**Location**: Swift:L597
**Swift**: `apiRejectCall`
**Haskell**: `NOT FOUND`

### apiSendCallOffer
**Location**: Swift:L598
**Swift**: `apiSendCallOffer`
**Haskell**: `NOT FOUND`

### apiSendCallAnswer
**Location**: Swift:L599
**Swift**: `apiSendCallAnswer`
**Haskell**: `NOT FOUND`

### apiSendCallExtraInfo
**Location**: Swift:L600
**Swift**: `apiSendCallExtraInfo`
**Haskell**: `NOT FOUND`

### apiEndCall
**Location**: Swift:L601
**Swift**: `apiEndCall`
**Haskell**: `NOT FOUND`

### apiGetCallInvitations
**Location**: Swift:L602
**Swift**: `apiGetCallInvitations`
**Haskell**: `NOT FOUND`

### apiCallStatus
**Location**: Swift:L603
**Swift**: `apiCallStatus`
**Haskell**: `NOT FOUND`

### apiChatRead
**Location**: Swift:L604
**Swift**: `apiChatRead`
**Haskell**: `NOT FOUND`

### apiChatItemsRead
**Location**: Swift:L605
**Swift**: `apiChatItemsRead`
**Haskell**: `NOT FOUND`

### apiChatUnread
**Location**: Swift:L606
**Swift**: `apiChatUnread`
**Haskell**: `NOT FOUND`

### receiveFile
**Location**: Swift:L607
**Swift**: `receiveFile`
**Haskell**: `NOT FOUND`

### setFileToReceive
**Location**: Swift:L608
**Swift**: `setFileToReceive`
**Haskell**: `NOT FOUND`

### cancelFile
**Location**: Swift:L609
**Swift**: `cancelFile`
**Haskell**: `NOT FOUND`

### setLocalDeviceName
**Location**: Swift:L610
**Swift**: `setLocalDeviceName`
**Haskell**: `NOT FOUND`

### connectRemoteCtrl
**Location**: Swift:L611
**Swift**: `connectRemoteCtrl`
**Haskell**: `NOT FOUND`

### confirmRemoteCtrl
**Location**: Swift:L612
**Swift**: `confirmRemoteCtrl`
**Haskell**: `NOT FOUND`

### verifyRemoteCtrlSession
**Location**: Swift:L613
**Swift**: `verifyRemoteCtrlSession`
**Haskell**: `NOT FOUND`

### listRemoteCtrls
**Location**: Swift:L614
**Swift**: `listRemoteCtrls`
**Haskell**: `NOT FOUND`

### stopRemoteCtrl
**Location**: Swift:L615
**Swift**: `stopRemoteCtrl`
**Haskell**: `NOT FOUND`

### deleteRemoteCtrl
**Location**: Swift:L616
**Swift**: `deleteRemoteCtrl`
**Haskell**: `NOT FOUND`

### apiUploadStandaloneFile
**Location**: Swift:L617
**Swift**: `apiUploadStandaloneFile`
**Haskell**: `NOT FOUND`

### apiDownloadStandaloneFile
**Location**: Swift:L618
**Swift**: `apiDownloadStandaloneFile`
**Haskell**: `NOT FOUND`

### apiStandaloneFileInfo
**Location**: Swift:L619
**Swift**: `apiStandaloneFileInfo`
**Haskell**: `NOT FOUND`

### apiRedeemBadgeCode
**Location**: Swift:L620
**Swift**: `apiRedeemBadgeCode`
**Haskell**: `NOT FOUND`

### apiGetBadgeState
**Location**: Swift:L621
**Swift**: `apiGetBadgeState`
**Haskell**: `NOT FOUND`

### apiGetBadgeLedger
**Location**: Swift:L622
**Swift**: `apiGetBadgeLedger`
**Haskell**: `NOT FOUND`

### apiAckBadgeAlert
**Location**: Swift:L623
**Swift**: `apiAckBadgeAlert`
**Haskell**: `NOT FOUND`

### showVersion
**Location**: Swift:L624
**Swift**: `showVersion`
**Haskell**: `NOT FOUND`

### getAgentSubsTotal
**Location**: Swift:L625
**Swift**: `getAgentSubsTotal`
**Haskell**: `NOT FOUND`

### getAgentServersSummary
**Location**: Swift:L626
**Swift**: `getAgentServersSummary`
**Haskell**: `NOT FOUND`

### resetAgentServersStats
**Location**: Swift:L627
**Swift**: `resetAgentServersStats`
**Haskell**: `NOT FOUND`

### string
**Location**: Swift:L628
**Swift**: `console command`
**Haskell**: `NOT FOUND`

### apiGetBinThereBots
**Location**: Swift:L629
**Swift**: `apiGetBinThereBots`
**Haskell**: `NOT FOUND`

### apiInsertBinThereBot
**Location**: Swift:L630
**Swift**: `apiInsertBinThereBot`
**Haskell**: `NOT FOUND`

### apiReportBinThereBotUse
**Location**: Swift:L631
**Swift**: `apiReportBinThereBotUse`
**Haskell**: `NOT FOUND`

### apiSyncBotDirectory
**Location**: Swift:L632
**Swift**: `apiSyncBotDirectory`
**Haskell**: `NOT FOUND`

### apiGetComputeBalance
**Location**: Swift:L633
**Swift**: `apiGetComputeBalance`
**Haskell**: `NOT FOUND`

### apiRecordComputePurchase
**Location**: Swift:L634
**Swift**: `apiRecordComputePurchase`
**Haskell**: `NOT FOUND`

### apiGetComputePurchases
**Location**: Swift:L635
**Swift**: `apiGetComputePurchases`
**Haskell**: `NOT FOUND`

### chatContentTypes
**Location**: Swift:L839
**Swift**: `content types: \(String(describing: types))`
**Haskell**: `NOT FOUND`

### serverOperatorConditions
**Location**: Swift:L844
**Swift**: `conditions: \(String(describing: conditions))`
**Haskell**: `NOT FOUND`

### usageConditions
**Location**: Swift:L851
**Swift**: `usageConditions: \(String(describing: usageConditions))\nacceptedConditions: \(String(describing: acceptedConditions))`
**Haskell**: `NOT FOUND`

### chatHelp
**Location**: Swift:L875
**Swift**: `helpSection: \(section.prefix(100))`
**Haskell**: `NOT FOUND`

### ntfToken
**Location**: Swift:L1822
**Swift**: `token: \(token)\nstatus: \(status.rawValue)\nntfMode: \(ntfMode.rawValue)\nntfServer: \(ntfServer)`
**Haskell**: `NOT FOUND`

### connNtfMessages
**Location**: Swift:L1824
**Swift**: `receivedMsgs: \(String(describing: receivedMsgs))`
**Haskell**: `NOT FOUND`

### remoteCtrlConnecting
**Location**: Swift:L1826
**Swift**: `remoteCtrl_:\n\(String(describing: remoteCtrl_))\nctrlAppInfo:\n\(String(describing: ctrlAppInfo))\nappVersion: \(appVersion)`
**Haskell**: `NOT FOUND`

### remoteCtrlConnected
**Location**: Swift:L1827
**Swift**: `\(String(describing: remoteCtrl))\ncompression: \(compression)`
**Haskell**: `NOT FOUND`

### versionInfo
**Location**: Swift:L1828
**Swift**: `\(String(describing: versionInfo))\n\nchat migrations: \(chatMigrations.map(\.upName))\n\nagent migrations: \(agentMigrations.map(\.upName))`
**Haskell**: `NOT FOUND`

### subscriptionStatus
**Location**: Swift:L2484
**Swift**: `server: \(server)\nsubscriptionStatus: \(String(describing: status))\nconnections: \(String(describing: conns))`
**Haskell**: `NOT FOUND`

### hostConnected
**Location**: Swift:L2545
**Swift**: `protocol: \(protocol_)\ntransportHost: \(transportHost)`
**Haskell**: `NOT FOUND`

### hostDisconnected
**Location**: Swift:L2546
**Swift**: `protocol: \(protocol_)\ntransportHost: \(transportHost)`
**Haskell**: `NOT FOUND`

### remoteCtrlFound
**Location**: Swift:L2547
**Swift**: `remoteCtrl:\n\(String(describing: remoteCtrl))\nctrlAppInfo_:\n\(String(describing: ctrlAppInfo_))\nappVersion: \(appVersion)\ncompatible: \(compatible)`
**Haskell**: `NOT FOUND`

### remoteCtrlSessionCode
**Location**: Swift:L2548
**Swift**: `remoteCtrl_:\n\(String(describing: remoteCtrl_))\nsessionCode: \(sessionCode)`
**Haskell**: `NOT FOUND`

### remoteCtrlStopped
**Location**: Swift:L2550
**Swift**: `remoteCtrl_: \(String(describing: remoteCtrl_))\nrcsState: \(String(describing: rcsState))\nrcStopReason: \(String(describing: rcStopReason))`
**Haskell**: `NOT FOUND`

### remoteHostSessionCode
**Location**: Swift:L2556
**Swift**: `remoteHost_: \(String(describing: remoteHost_))\nsessionCode: \(sessionCode)`
**Haskell**: `NOT FOUND`

### newRemoteHost
**Location**: Swift:L2557
**Swift**: `remoteHost: \(String(describing: remoteHost))`
**Haskell**: `NOT FOUND`

### remoteHostConnected
**Location**: Swift:L2558
**Swift**: `remoteHost: \(String(describing: remoteHost))\ncompression: \(compression)`
**Haskell**: `NOT FOUND`

### remoteHostStopped
**Location**: Swift:L2559
**Swift**: `remoteHostId_: \(String(describing: remoteHostId_))\nrhsState: \(String(describing: rhsState))\nrhStopReason: \(String(describing: rhStopReason))`
**Haskell**: `NOT FOUND`

### connectionsDiff
**Location**: Swift:L2562
**Swift**: `userIds: \(String(describing: userIds))\nconnIds: \(String(describing: connIds))`
**Haskell**: `NOT FOUND`

### serviceSubStatus
**Location**: Swift:L2564
**Swift**: `server: \(server)\nserviceSubEvent: \(String(describing: serviceSubEvent))`
**Haskell**: `NOT FOUND`

### serviceReplySent
**Location**: Swift:L2568
**Swift**: `connectionId: \(connectionId)`
**Haskell**: `NOT FOUND`

### connectionInactive
**Location**: Swift:L2582
**Swift**: `connectionEntity: \(String(describing: connectionEntity))\ninactive: \(inactive)`
**Haskell**: `NOT FOUND`

### agentRcvQueuesDeleted
**Location**: Swift:L2583
**Swift**: `deletedRcvQueues: \(String(describing: deletedRcvQueues))`
**Haskell**: `NOT FOUND`

### agentConnsDeleted
**Location**: Swift:L2584
**Swift**: `agentConnIds: \(String(describing: agentConnIds))`
**Haskell**: `NOT FOUND`

### agentUserDeleted
**Location**: Swift:L2585
**Swift**: `agentUserId: \(agentUserId)`
**Haskell**: `NOT FOUND`

### chatErrors
**Location**: Swift:L2587
**Swift**: `chatErrors: \(String(describing: chatErrors))`
**Haskell**: `NOT FOUND`

### timedAction
**Location**: Swift:L2588
**Swift**: `action: \(action)\ndurationMilliseconds: \(durationMilliseconds)`
**Haskell**: `NOT FOUND`

### customChatEvent
**Location**: Swift:L2590
**Swift**: `\(String(describing: user_))\nresponse: \(response)`
**Haskell**: `NOT FOUND`

### last
**Location**: Swift:L3451
**Swift**: `count=\(count)`
**Haskell**: `NOT FOUND`

### after
**Location**: Swift:L3452
**Swift**: `after=\(chatItemId) count=\(count)`
**Haskell**: `NOT FOUND`

### before
**Location**: Swift:L3453
**Swift**: `before=\(chatItemId) count=\(count)`
**Haskell**: `NOT FOUND`

### around
**Location**: Swift:L3454
**Swift**: `around=\(chatItemId) count=\(count)`
**Haskell**: `NOT FOUND`

### initial
**Location**: Swift:L3455
**Swift**: `initial=\(count)`
**Haskell**: `NOT FOUND`

### off
**Location**: Swift:L3644
**Swift**: `arrow.clockwise`
**Haskell**: `NOT FOUND`

### periodic
**Location**: Swift:L3645
**Swift**: `timer`
**Haskell**: `NOT FOUND`

### instant
**Location**: Swift:L3646
**Swift**: `bolt`
**Haskell**: `NOT FOUND`

## All Commands

| Status | Command | Swift Pattern | Haskell Pattern |
|--------|---------|---------------|-----------------|
| ❌ | after | `after=\(chatItemId) count=\(count)` | `NOT FOUND` |
| ❌ | agentConnsDeleted | `agentConnIds: \(String(describing: agentConnIds))` | `NOT FOUND` |
| ❌ | agentRcvQueuesDeleted | `deletedRcvQueues: \(String(describing: deletedRcvQ...` | `NOT FOUND` |
| ❌ | agentUserDeleted | `agentUserId: \(agentUserId)` | `NOT FOUND` |
| ❌ | apiAbortSwitchContact | `/_abort switch @\(contactId)` | `NOT FOUND` |
| ❌ | apiAbortSwitchContact | `apiAbortSwitchContact` | `NOT FOUND` |
| ❌ | apiAbortSwitchGroupMember | `/_abort switch #\(groupId) \(groupMemberId)` | `NOT FOUND` |
| ❌ | apiAbortSwitchGroupMember | `apiAbortSwitchGroupMember` | `NOT FOUND` |
| ❌ | apiAcceptConditions | `/_accept_conditions \(conditionsId) \(joinedIds(op...` | `NOT FOUND` |
| ❌ | apiAcceptConditions | `apiAcceptConditions` | `NOT FOUND` |
| ❌ | apiAcceptContact | `/_accept incognito=\(onOff(incognito)) \(contactRe...` | `NOT FOUND` |
| ❌ | apiAcceptContact | `apiAcceptContact` | `NOT FOUND` |
| ❌ | apiAcceptMember | `/_accept member #\(groupId) \(groupMemberId) \(mem...` | `NOT FOUND` |
| ❌ | apiAcceptMember | `apiAcceptMember` | `NOT FOUND` |
| ❌ | apiAcceptMemberContact | `/_accept member contact @\(contactId)` | `NOT FOUND` |
| ❌ | apiAcceptMemberContact | `apiAcceptMemberContact` | `NOT FOUND` |
| ❌ | apiAckBadgeAlert | `apiAckBadgeAlert` | `NOT FOUND` |
| ❌ | apiActivateChat | `/_app activate restore=\(onOff(restore))` | `NOT FOUND` |
| ❌ | apiActivateChat | `apiActivateChat` | `NOT FOUND` |
| ❌ | apiAddContact | `/_connect \(userId) incognito=\(onOff(incognito))` | `NOT FOUND` |
| ❌ | apiAddContact | `apiAddContact` | `NOT FOUND` |
| ❌ | apiAddGroupRelays | `/_add relays #\(groupId) \(relayIds.map(String.ini...` | `NOT FOUND` |
| ❌ | apiAddGroupRelays | `apiAddGroupRelays` | `NOT FOUND` |
| ❌ | apiAddGroupShortLink | `/_short link #\(groupId)` | `NOT FOUND` |
| ❌ | apiAddGroupShortLink | `apiAddGroupShortLink` | `NOT FOUND` |
| ❌ | apiAddMember | `/_add #\(groupId) \(contactId) \(memberRole)` | `NOT FOUND` |
| ❌ | apiAddMember | `apiAddMember` | `NOT FOUND` |
| ❌ | apiAddMyAddressShortLink | `/_short_link_address \(userId)` | `NOT FOUND` |
| ❌ | apiAddMyAddressShortLink | `apiAddMyAddressShortLink` | `NOT FOUND` |
| ❌ | apiArchiveReceivedReports | `/_archive reports #\(groupId)` | `NOT FOUND` |
| ❌ | apiArchiveReceivedReports | `apiArchiveReceivedReports` | `NOT FOUND` |
| ❌ | apiBlockMembersForAll | `/_block #\(groupId) \(memberIds.map({ ` | `NOT FOUND` |
| ❌ | apiBlockMembersForAll | `apiBlockMembersForAll` | `NOT FOUND` |
| ❌ | apiCallStatus | `/_call status @\(contact.apiId) \(callStatus.rawVa...` | `NOT FOUND` |
| ❌ | apiCallStatus | `apiCallStatus` | `NOT FOUND` |
| ❌ | apiChangeConnectionUser | `/_set conn user :\(connId) \(userId)` | `NOT FOUND` |
| ❌ | apiChangeConnectionUser | `apiChangeConnectionUser` | `NOT FOUND` |
| ❌ | apiChangePreparedContactUser | `/_set contact user @\(contactId) \(newUserId)` | `NOT FOUND` |
| ❌ | apiChangePreparedContactUser | `apiChangePreparedContactUser` | `NOT FOUND` |
| ❌ | apiChangePreparedGroupUser | `/_set group user #\(groupId) \(newUserId)` | `NOT FOUND` |
| ❌ | apiChangePreparedGroupUser | `apiChangePreparedGroupUser` | `NOT FOUND` |
| ❌ | apiChatItemReaction | `/_reaction \(ref(type, id, scope: scope)) \(itemId...` | `NOT FOUND` |
| ❌ | apiChatItemReaction | `apiChatItemReaction` | `NOT FOUND` |
| ❌ | apiChatItemsRead | `/_read chat items \(ref(type, id, scope: scope)) \...` | `NOT FOUND` |
| ❌ | apiChatItemsRead | `apiChatItemsRead` | `NOT FOUND` |
| ❌ | apiChatRead | `/_read chat \(ref(type, id, scope: scope))` | `NOT FOUND` |
| ❌ | apiChatRead | `apiChatRead` | `NOT FOUND` |
| ❌ | apiChatUnread | `/_unread chat \(ref(type, id, scope: nil)) \(onOff...` | `NOT FOUND` |
| ❌ | apiChatUnread | `apiChatUnread` | `NOT FOUND` |
| ❌ | apiCheckToken | `/_ntf check \(token.cmdString)` | `NOT FOUND` |
| ❌ | apiCheckToken | `apiCheckToken` | `NOT FOUND` |
| ❌ | apiClearChat | `/_clear chat \(ref(type, id, scope: nil))` | `NOT FOUND` |
| ❌ | apiClearChat | `apiClearChat` | `NOT FOUND` |
| ❌ | apiConnect | `/_connect \(userId) incognito=\(onOff(incognito)) ...` | `NOT FOUND` |
| ❌ | apiConnect | `apiConnect` | `NOT FOUND` |
| ❌ | apiConnectContactViaAddress | `/_connect contact \(userId) incognito=\(onOff(inco...` | `NOT FOUND` |
| ❌ | apiConnectContactViaAddress | `apiConnectContactViaAddress` | `NOT FOUND` |
| ❌ | apiConnectPlan | `apiConnectPlan` | `NOT FOUND` |
| ❌ | apiConnectPreparedContact | `/_connect contact @\(contactId) incognito=\(onOff(...` | `NOT FOUND` |
| ❌ | apiConnectPreparedContact | `apiConnectPreparedContact` | `NOT FOUND` |
| ❌ | apiConnectPreparedGroup | `/_connect group #\(groupId) incognito=\(onOff(inco...` | `NOT FOUND` |
| ❌ | apiConnectPreparedGroup | `apiConnectPreparedGroup` | `NOT FOUND` |
| ❌ | apiContactInfo | `/_info @\(contactId)` | `NOT FOUND` |
| ❌ | apiContactInfo | `apiContactInfo` | `NOT FOUND` |
| ❌ | apiContactQueueInfo | `/_queue info @\(contactId)` | `NOT FOUND` |
| ❌ | apiContactQueueInfo | `apiContactQueueInfo` | `NOT FOUND` |
| ❌ | apiCreateChatItems | `apiCreateChatItems` | `NOT FOUND` |
| ❌ | apiCreateChatTag | `/_create tag \(encodeJSON(tag))` | `NOT FOUND` |
| ❌ | apiCreateChatTag | `apiCreateChatTag` | `NOT FOUND` |
| ❌ | apiCreateGroupLink | `/_create link #\(groupId) \(memberRole)` | `NOT FOUND` |
| ❌ | apiCreateGroupLink | `apiCreateGroupLink` | `NOT FOUND` |
| ❌ | apiCreateMemberContact | `/_create member contact #\(groupId) \(groupMemberI...` | `NOT FOUND` |
| ❌ | apiCreateMemberContact | `apiCreateMemberContact` | `NOT FOUND` |
| ❌ | apiCreateMyAddress | `/_address \(userId)` | `NOT FOUND` |
| ❌ | apiCreateMyAddress | `apiCreateMyAddress` | `NOT FOUND` |
| ❌ | apiDeleteChat | `/_delete \(ref(type, id, scope: nil)) \(chatDelete...` | `NOT FOUND` |
| ❌ | apiDeleteChat | `apiDeleteChat` | `NOT FOUND` |
| ❌ | apiDeleteChatItem | `/_delete item \(ref(type, id, scope: scope)) \(ite...` | `NOT FOUND` |
| ❌ | apiDeleteChatItem | `apiDeleteChatItem` | `NOT FOUND` |
| ❌ | apiDeleteChatTag | `/_delete tag \(tagId)` | `NOT FOUND` |
| ❌ | apiDeleteChatTag | `apiDeleteChatTag` | `NOT FOUND` |
| ❌ | apiDeleteGroupLink | `/_delete link #\(groupId)` | `NOT FOUND` |
| ❌ | apiDeleteGroupLink | `apiDeleteGroupLink` | `NOT FOUND` |
| ❌ | apiDeleteMemberChatItem | `/_delete member item #\(groupId) \(itemIds.map({ ` | `NOT FOUND` |
| ❌ | apiDeleteMemberChatItem | `apiDeleteMemberChatItem` | `NOT FOUND` |
| ❌ | apiDeleteMemberSupportChat | `/_delete member chat #\(groupId) \(groupMemberId)` | `NOT FOUND` |
| ❌ | apiDeleteMemberSupportChat | `apiDeleteMemberSupportChat` | `NOT FOUND` |
| ❌ | apiDeleteMyAddress | `/_delete_address \(userId)` | `NOT FOUND` |
| ❌ | apiDeleteMyAddress | `apiDeleteMyAddress` | `NOT FOUND` |
| ❌ | apiDeleteReceivedReports | `/_delete reports #\(groupId) \(itemIds.map({ ` | `NOT FOUND` |
| ❌ | apiDeleteReceivedReports | `apiDeleteReceivedReports` | `NOT FOUND` |
| ❌ | apiDeleteStorage | `/_db delete` | `NOT FOUND` |
| ❌ | apiDeleteStorage | `apiDeleteStorage` | `NOT FOUND` |
| ❌ | apiDeleteToken | `/_ntf delete \(token.cmdString)` | `NOT FOUND` |
| ❌ | apiDeleteToken | `apiDeleteToken` | `NOT FOUND` |
| ❌ | apiDeleteUser | `/_delete user \(userId) del_smp=\(onOff(delSMPQueu...` | `NOT FOUND` |
| ❌ | apiDeleteUser | `apiDeleteUser` | `NOT FOUND` |
| ❌ | apiDownloadStandaloneFile | `/_download \(userId) \(sanitizeFFIParam(link, maxL...` | `NOT FOUND` |
| ❌ | apiDownloadStandaloneFile | `apiDownloadStandaloneFile` | `NOT FOUND` |
| ❌ | apiEndCall | `/_call end @\(contact.apiId)` | `NOT FOUND` |
| ❌ | apiEndCall | `apiEndCall` | `NOT FOUND` |
| ❌ | apiExportArchive | `/_db export \(encodeJSON(cfg))` | `NOT FOUND` |
| ❌ | apiExportArchive | `apiExportArchive` | `NOT FOUND` |
| ❌ | apiForwardChatItems | `apiForwardChatItems` | `NOT FOUND` |
| ❌ | apiGetBadgeLedger | `/_badge ledger \(userId) \(badgePurchaseId)` | `NOT FOUND` |
| ❌ | apiGetBadgeLedger | `apiGetBadgeLedger` | `NOT FOUND` |
| ❌ | apiGetBadgeState | `/_badge state \(userId)` | `NOT FOUND` |
| ❌ | apiGetBadgeState | `apiGetBadgeState` | `NOT FOUND` |
| ❌ | apiGetBinThereBots | `/_binthere_bots \(userId) \(botType)` | `NOT FOUND` |
| ❌ | apiGetBinThereBots | `apiGetBinThereBots` | `NOT FOUND` |
| ❌ | apiGetCallInvitations | `/_call get` | `NOT FOUND` |
| ❌ | apiGetCallInvitations | `apiGetCallInvitations` | `NOT FOUND` |
| ❌ | apiGetChat | `apiGetChat` | `NOT FOUND` |
| ❌ | apiGetChatContentTypes | `/_get content types \(chatId)\(scopeRef(scope))` | `NOT FOUND` |
| ❌ | apiGetChatContentTypes | `apiGetChatContentTypes` | `NOT FOUND` |
| ❌ | apiGetChatItemInfo | `/_get item info \(ref(type, id, scope: scope)) \(i...` | `NOT FOUND` |
| ❌ | apiGetChatItemInfo | `apiGetChatItemInfo` | `NOT FOUND` |
| ❌ | apiGetChatItemTTL | `/_ttl \(userId)` | `NOT FOUND` |
| ❌ | apiGetChatItemTTL | `apiGetChatItemTTL` | `NOT FOUND` |
| ❌ | apiGetChatTags | `/_get tags \(userId)` | `NOT FOUND` |
| ❌ | apiGetChatTags | `apiGetChatTags` | `NOT FOUND` |
| ❌ | apiGetChats | `/_get chats \(userId) pcc=on` | `NOT FOUND` |
| ❌ | apiGetChats | `apiGetChats` | `NOT FOUND` |
| ❌ | apiGetComputeBalance | `/_compute_balance \(userId)` | `NOT FOUND` |
| ❌ | apiGetComputeBalance | `apiGetComputeBalance` | `NOT FOUND` |
| ❌ | apiGetComputePurchases | `/_compute_purchases \(userId)` | `NOT FOUND` |
| ❌ | apiGetComputePurchases | `apiGetComputePurchases` | `NOT FOUND` |
| ❌ | apiGetConnNtfMessages | `/_ntf conn messages \(connMsgReqs.map { $0.cmdStri...` | `NOT FOUND` |
| ❌ | apiGetConnNtfMessages | `apiGetConnNtfMessages` | `NOT FOUND` |
| ❌ | apiGetContactCode | `/_get code @\(contactId)` | `NOT FOUND` |
| ❌ | apiGetContactCode | `apiGetContactCode` | `NOT FOUND` |
| ❌ | apiGetGroupLink | `/_get link #\(groupId)` | `NOT FOUND` |
| ❌ | apiGetGroupLink | `apiGetGroupLink` | `NOT FOUND` |
| ❌ | apiGetGroupMemberCode | `/_get code #\(groupId) \(groupMemberId)` | `NOT FOUND` |
| ❌ | apiGetGroupMemberCode | `apiGetGroupMemberCode` | `NOT FOUND` |
| ❌ | apiGetGroupRelays | `/_get relays #\(groupId)` | `NOT FOUND` |
| ❌ | apiGetGroupRelays | `apiGetGroupRelays` | `NOT FOUND` |
| ❌ | apiGetNetworkConfig | `/network` | `NOT FOUND` |
| ❌ | apiGetNetworkConfig | `apiGetNetworkConfig` | `NOT FOUND` |
| ❌ | apiGetNtfConns | `/_ntf conns \(nonce) \(encNtfInfo)` | `NOT FOUND` |
| ❌ | apiGetNtfConns | `apiGetNtfConns` | `NOT FOUND` |
| ❌ | apiGetNtfToken | `/_ntf get ` | `NOT FOUND` |
| ❌ | apiGetNtfToken | `apiGetNtfToken` | `NOT FOUND` |
| ❌ | apiGetReactionMembers | `/_reaction members \(userId) #\(groupId) \(itemId)...` | `NOT FOUND` |
| ❌ | apiGetReactionMembers | `apiGetReactionMembers` | `NOT FOUND` |
| ❌ | apiGetServerOperators | `/_operators` | `NOT FOUND` |
| ❌ | apiGetServerOperators | `apiGetServerOperators` | `NOT FOUND` |
| ❌ | apiGetSettings | `/_get app settings \(encodeJSON(settings))` | `NOT FOUND` |
| ❌ | apiGetSettings | `apiGetSettings` | `NOT FOUND` |
| ❌ | apiGetUpdatedGroupLinkData | `/_get group link data #\(groupId)` | `NOT FOUND` |
| ❌ | apiGetUpdatedGroupLinkData | `apiGetUpdatedGroupLinkData` | `NOT FOUND` |
| ❌ | apiGetUsageConditions | `/_conditions` | `NOT FOUND` |
| ❌ | apiGetUsageConditions | `apiGetUsageConditions` | `NOT FOUND` |
| ❌ | apiGetUserServers | `/_servers \(userId)` | `NOT FOUND` |
| ❌ | apiGetUserServers | `apiGetUserServers` | `NOT FOUND` |
| ❌ | apiGroupLinkMemberRole | `/_set link role #\(groupId) \(memberRole)` | `NOT FOUND` |
| ❌ | apiGroupLinkMemberRole | `apiGroupLinkMemberRole` | `NOT FOUND` |
| ❌ | apiGroupMemberInfo | `/_info #\(groupId) \(groupMemberId)` | `NOT FOUND` |
| ❌ | apiGroupMemberInfo | `apiGroupMemberInfo` | `NOT FOUND` |
| ❌ | apiGroupMemberQueueInfo | `/_queue info #\(groupId) \(groupMemberId)` | `NOT FOUND` |
| ❌ | apiGroupMemberQueueInfo | `apiGroupMemberQueueInfo` | `NOT FOUND` |
| ❌ | apiHideUser | `/_hide user \(userId) \(encodeJSON(viewPwd))` | `NOT FOUND` |
| ❌ | apiHideUser | `apiHideUser` | `NOT FOUND` |
| ❌ | apiImportArchive | `/_db import \(encodeJSON(cfg))` | `NOT FOUND` |
| ❌ | apiImportArchive | `apiImportArchive` | `NOT FOUND` |
| ❌ | apiInsertBinThereBot | `/_binthere_bot_add \(userId) \(address) \(name ?? ` | `NOT FOUND` |
| ❌ | apiInsertBinThereBot | `apiInsertBinThereBot` | `NOT FOUND` |
| ❌ | apiJoinGroup | `/_join #\(groupId)` | `NOT FOUND` |
| ❌ | apiJoinGroup | `apiJoinGroup` | `NOT FOUND` |
| ❌ | apiLeaveGroup | `/_leave #\(groupId)` | `NOT FOUND` |
| ❌ | apiLeaveGroup | `apiLeaveGroup` | `NOT FOUND` |
| ❌ | apiListContacts | `/_contacts \(userId)` | `NOT FOUND` |
| ❌ | apiListContacts | `apiListContacts` | `NOT FOUND` |
| ❌ | apiListMembers | `/_members #\(groupId)` | `NOT FOUND` |
| ❌ | apiListMembers | `apiListMembers` | `NOT FOUND` |
| ❌ | apiMembersRole | `/_member role #\(groupId) \(memberIds.map({ ` | `NOT FOUND` |
| ❌ | apiMembersRole | `apiMembersRole` | `NOT FOUND` |
| ❌ | apiMuteUser | `/_mute user \(userId)` | `NOT FOUND` |
| ❌ | apiMuteUser | `apiMuteUser` | `NOT FOUND` |
| ❌ | apiNewGroup | `/_group \(userId) incognito=\(onOff(incognito)) \(...` | `NOT FOUND` |
| ❌ | apiNewGroup | `apiNewGroup` | `NOT FOUND` |
| ❌ | apiNewPublicGroup | `/_public group \(userId) incognito=\(onOff(incogni...` | `NOT FOUND` |
| ❌ | apiNewPublicGroup | `apiNewPublicGroup` | `NOT FOUND` |
| ❌ | apiPlanForwardChatItems | `/_forward plan \(ref(type, id, scope: scope)) \(it...` | `NOT FOUND` |
| ❌ | apiPlanForwardChatItems | `apiPlanForwardChatItems` | `NOT FOUND` |
| ❌ | apiPrepareContact | `/_prepare contact \(userId) \(connLink.connFullLin...` | `NOT FOUND` |
| ❌ | apiPrepareContact | `apiPrepareContact` | `NOT FOUND` |
| ❌ | apiPrepareGroup | `/_prepare group \(userId) \(connLink.connFullLink)...` | `NOT FOUND` |
| ❌ | apiPrepareGroup | `apiPrepareGroup` | `NOT FOUND` |
| ❌ | apiRecordComputePurchase | `/_compute_purchase_record \(userId) \(encodeJSON(p...` | `NOT FOUND` |
| ❌ | apiRecordComputePurchase | `apiRecordComputePurchase` | `NOT FOUND` |
| ❌ | apiRedeemBadgeCode | `/_redeem_badge_code \(userId) \(code)` | `NOT FOUND` |
| ❌ | apiRedeemBadgeCode | `apiRedeemBadgeCode` | `NOT FOUND` |
| ❌ | apiRegisterToken | `/_ntf register \(token.cmdString) \(notificationMo...` | `NOT FOUND` |
| ❌ | apiRegisterToken | `apiRegisterToken` | `NOT FOUND` |
| ❌ | apiRejectCall | `/_call reject @\(contact.apiId)` | `NOT FOUND` |
| ❌ | apiRejectCall | `apiRejectCall` | `NOT FOUND` |
| ❌ | apiRejectContact | `/_reject \(contactReqId)` | `NOT FOUND` |
| ❌ | apiRejectContact | `apiRejectContact` | `NOT FOUND` |
| ❌ | apiRemoveMembers | `/_remove #\(groupId) \(memberIds.map({ ` | `NOT FOUND` |
| ❌ | apiRemoveMembers | `apiRemoveMembers` | `NOT FOUND` |
| ❌ | apiReorderChatTags | `/_reorder tags \(tagIds.map({ ` | `NOT FOUND` |
| ❌ | apiReorderChatTags | `apiReorderChatTags` | `NOT FOUND` |
| ❌ | apiReportBinThereBotUse | `/_binthere_bot_use \(userId) \(botId)` | `NOT FOUND` |
| ❌ | apiReportBinThereBotUse | `apiReportBinThereBotUse` | `NOT FOUND` |
| ❌ | apiReportMessage | `apiReportMessage` | `NOT FOUND` |
| ❌ | apiSaveSettings | `/_save app settings \(encodeJSON(settings))` | `NOT FOUND` |
| ❌ | apiSaveSettings | `apiSaveSettings` | `NOT FOUND` |
| ❌ | apiSendCallAnswer | `/_call answer @\(contact.apiId) \(encodeJSON(answe...` | `NOT FOUND` |
| ❌ | apiSendCallAnswer | `apiSendCallAnswer` | `NOT FOUND` |
| ❌ | apiSendCallExtraInfo | `/_call extra @\(contact.apiId) \(encodeJSON(extraI...` | `NOT FOUND` |
| ❌ | apiSendCallExtraInfo | `apiSendCallExtraInfo` | `NOT FOUND` |
| ❌ | apiSendCallInvitation | `/_call invite @\(contact.apiId) \(encodeJSON(callT...` | `NOT FOUND` |
| ❌ | apiSendCallInvitation | `apiSendCallInvitation` | `NOT FOUND` |
| ❌ | apiSendCallOffer | `/_call offer @\(contact.apiId) \(encodeJSON(callOf...` | `NOT FOUND` |
| ❌ | apiSendCallOffer | `apiSendCallOffer` | `NOT FOUND` |
| ❌ | apiSendMemberContactInvitation | `/_invite member contact @\(contactId) \(mc.cmdStri...` | `NOT FOUND` |
| ❌ | apiSendMemberContactInvitation | `apiSendMemberContactInvitation` | `NOT FOUND` |
| ❌ | apiSendMessages | `apiSendMessages` | `NOT FOUND` |
| ❌ | apiSetActiveUser | `/_user \(userId)\(maybePwd(viewPwd))` | `NOT FOUND` |
| ❌ | apiSetActiveUser | `apiSetActiveUser` | `NOT FOUND` |
| ❌ | apiSetAddressSettings | `/_address_settings \(userId) \(encodeJSON(addressS...` | `NOT FOUND` |
| ❌ | apiSetAddressSettings | `apiSetAddressSettings` | `NOT FOUND` |
| ❌ | apiSetAppFilePaths | `/set file paths \(encodeJSON(AppFilePaths(appFiles...` | `NOT FOUND` |
| ❌ | apiSetAppFilePaths | `apiSetAppFilePaths` | `NOT FOUND` |
| ❌ | apiSetChatItemTTL | `/_ttl \(userId) \(chatItemTTLStr(seconds: seconds)...` | `NOT FOUND` |
| ❌ | apiSetChatItemTTL | `apiSetChatItemTTL` | `NOT FOUND` |
| ❌ | apiSetChatSettings | `/_settings \(ref(type, id, scope: nil)) \(encodeJS...` | `NOT FOUND` |
| ❌ | apiSetChatSettings | `apiSetChatSettings` | `NOT FOUND` |
| ❌ | apiSetChatTTL | `/_ttl \(userId) \(ref(type, id, scope: nil)) \(cha...` | `NOT FOUND` |
| ❌ | apiSetChatTTL | `apiSetChatTTL` | `NOT FOUND` |
| ❌ | apiSetChatTags | `/_tags \(ref(type, id, scope: nil)) \(tagIds.map({...` | `NOT FOUND` |
| ❌ | apiSetChatTags | `apiSetChatTags` | `NOT FOUND` |
| ❌ | apiSetChatUIThemes | `/_set theme \(chatId) \(themes != nil ? encodeJSON...` | `NOT FOUND` |
| ❌ | apiSetChatUIThemes | `apiSetChatUIThemes` | `NOT FOUND` |
| ❌ | apiSetClientService | `apiSetClientService` | `NOT FOUND` |
| ❌ | apiSetConditionsNotified | `/_conditions_notified \(conditionsId)` | `NOT FOUND` |
| ❌ | apiSetConditionsNotified | `apiSetConditionsNotified` | `NOT FOUND` |
| ❌ | apiSetConnectionAlias | `/_set alias :\(connId) \(sanitizeFFIParam(localAli...` | `NOT FOUND` |
| ❌ | apiSetConnectionAlias | `apiSetConnectionAlias` | `NOT FOUND` |
| ❌ | apiSetConnectionIncognito | `/_set incognito :\(connId) \(onOff(incognito))` | `NOT FOUND` |
| ❌ | apiSetConnectionIncognito | `apiSetConnectionIncognito` | `NOT FOUND` |
| ❌ | apiSetContactAlias | `/_set alias @\(contactId) \(sanitizeFFIParam(local...` | `NOT FOUND` |
| ❌ | apiSetContactAlias | `apiSetContactAlias` | `NOT FOUND` |
| ❌ | apiSetContactPrefs | `/_set prefs @\(contactId) \(encodeJSON(preferences...` | `NOT FOUND` |
| ❌ | apiSetContactPrefs | `apiSetContactPrefs` | `NOT FOUND` |
| ❌ | apiSetEncryptLocalFiles | `/_files_encrypt \(onOff(enable))` | `NOT FOUND` |
| ❌ | apiSetEncryptLocalFiles | `apiSetEncryptLocalFiles` | `NOT FOUND` |
| ❌ | apiSetGroupAlias | `/_set alias #\(groupId) \(sanitizeFFIParam(localAl...` | `NOT FOUND` |
| ❌ | apiSetGroupAlias | `apiSetGroupAlias` | `NOT FOUND` |
| ❌ | apiSetMemberSettings | `/_member settings #\(groupId) \(groupMemberId) \(e...` | `NOT FOUND` |
| ❌ | apiSetMemberSettings | `apiSetMemberSettings` | `NOT FOUND` |
| ❌ | apiSetNetworkConfig | `/_network \(encodeJSON(networkConfig))` | `NOT FOUND` |
| ❌ | apiSetNetworkConfig | `apiSetNetworkConfig` | `NOT FOUND` |
| ❌ | apiSetNetworkInfo | `/_network info \(encodeJSON(networkInfo))` | `NOT FOUND` |
| ❌ | apiSetNetworkInfo | `apiSetNetworkInfo` | `NOT FOUND` |
| ❌ | apiSetProfileAddress | `/_profile_address \(userId) \(onOff(on))` | `NOT FOUND` |
| ❌ | apiSetProfileAddress | `apiSetProfileAddress` | `NOT FOUND` |
| ❌ | apiSetServerOperators | `/_operators \(encodeJSON(operators))` | `NOT FOUND` |
| ❌ | apiSetServerOperators | `apiSetServerOperators` | `NOT FOUND` |
| ❌ | apiSetUserAutoAcceptGroupInvitations | `apiSetUserAutoAcceptGroupInvitations` | `NOT FOUND` |
| ❌ | apiSetUserAutoAcceptMemberContacts | `apiSetUserAutoAcceptMemberContacts` | `NOT FOUND` |
| ❌ | apiSetUserChatRelay | `apiSetUserChatRelay` | `NOT FOUND` |
| ❌ | apiSetUserContactReceipts | `apiSetUserContactReceipts` | `NOT FOUND` |
| ❌ | apiSetUserGroupReceipts | `apiSetUserGroupReceipts` | `NOT FOUND` |
| ❌ | apiSetUserServers | `/_servers \(userId) \(encodeJSON(userServers))` | `NOT FOUND` |
| ❌ | apiSetUserServers | `apiSetUserServers` | `NOT FOUND` |
| ❌ | apiSetUserUIThemes | `/_set theme user \(userId) \(themes != nil ? encod...` | `NOT FOUND` |
| ❌ | apiSetUserUIThemes | `apiSetUserUIThemes` | `NOT FOUND` |
| ❌ | apiShareChatMsgContent | `apiShareChatMsgContent` | `NOT FOUND` |
| ❌ | apiShowMyAddress | `/_show_address \(userId)` | `NOT FOUND` |
| ❌ | apiShowMyAddress | `apiShowMyAddress` | `NOT FOUND` |
| ❌ | apiStandaloneFileInfo | `/_download info \(sanitizeFFIParam(link, maxLen: 4...` | `NOT FOUND` |
| ❌ | apiStandaloneFileInfo | `apiStandaloneFileInfo` | `NOT FOUND` |
| ❌ | apiStopChat | `/_stop` | `NOT FOUND` |
| ❌ | apiStopChat | `apiStopChat` | `NOT FOUND` |
| ❌ | apiStorageEncryption | `/_db encryption \(encodeJSON(cfg))` | `NOT FOUND` |
| ❌ | apiStorageEncryption | `apiStorageEncryption` | `NOT FOUND` |
| ❌ | apiSuspendChat | `/_app suspend \(timeoutMicroseconds)` | `NOT FOUND` |
| ❌ | apiSuspendChat | `apiSuspendChat` | `NOT FOUND` |
| ❌ | apiSwitchContact | `/_switch @\(contactId)` | `NOT FOUND` |
| ❌ | apiSwitchContact | `apiSwitchContact` | `NOT FOUND` |
| ❌ | apiSwitchGroupMember | `/_switch #\(groupId) \(groupMemberId)` | `NOT FOUND` |
| ❌ | apiSwitchGroupMember | `apiSwitchGroupMember` | `NOT FOUND` |
| ❌ | apiSyncBotDirectory | `/_bot_directory_sync \(userId) \(json)` | `NOT FOUND` |
| ❌ | apiSyncBotDirectory | `apiSyncBotDirectory` | `NOT FOUND` |
| ❌ | apiSyncContactRatchet | `apiSyncContactRatchet` | `NOT FOUND` |
| ❌ | apiSyncGroupMemberRatchet | `apiSyncGroupMemberRatchet` | `NOT FOUND` |
| ❌ | apiTestChatRelay | `/_relay test \(userId) \(address)` | `NOT FOUND` |
| ❌ | apiTestChatRelay | `apiTestChatRelay` | `NOT FOUND` |
| ❌ | apiTestProtoServer | `/_server test \(userId) \(server)` | `NOT FOUND` |
| ❌ | apiTestProtoServer | `apiTestProtoServer` | `NOT FOUND` |
| ❌ | apiUnhideUser | `/_unhide user \(userId) \(encodeJSON(viewPwd))` | `NOT FOUND` |
| ❌ | apiUnhideUser | `apiUnhideUser` | `NOT FOUND` |
| ❌ | apiUnmuteUser | `/_unmute user \(userId)` | `NOT FOUND` |
| ❌ | apiUnmuteUser | `apiUnmuteUser` | `NOT FOUND` |
| ❌ | apiUpdateChatItem | `/_update item \(ref(type, id, scope: scope)) \(ite...` | `NOT FOUND` |
| ❌ | apiUpdateChatItem | `apiUpdateChatItem` | `NOT FOUND` |
| ❌ | apiUpdateChatTag | `/_update tag \(tagId) \(encodeJSON(tagData))` | `NOT FOUND` |
| ❌ | apiUpdateChatTag | `apiUpdateChatTag` | `NOT FOUND` |
| ❌ | apiUpdateGroupProfile | `/_group_profile #\(groupId) \(encodeJSON(groupProf...` | `NOT FOUND` |
| ❌ | apiUpdateGroupProfile | `apiUpdateGroupProfile` | `NOT FOUND` |
| ❌ | apiUpdateProfile | `/_profile \(userId) \(encodeJSON(profile))` | `NOT FOUND` |
| ❌ | apiUpdateProfile | `apiUpdateProfile` | `NOT FOUND` |
| ❌ | apiUploadStandaloneFile | `/_upload \(userId) \(sanitizeFFIParam(file.filePat...` | `NOT FOUND` |
| ❌ | apiUploadStandaloneFile | `apiUploadStandaloneFile` | `NOT FOUND` |
| ❌ | apiValidateServers | `/_validate_servers \(userId) \(encodeJSON(userServ...` | `NOT FOUND` |
| ❌ | apiValidateServers | `apiValidateServers` | `NOT FOUND` |
| ❌ | apiVerifyContact | `/_verify code @\(contactId) \(connectionCode)` | `NOT FOUND` |
| ❌ | apiVerifyContact | `/_verify code @\(contactId)` | `NOT FOUND` |
| ❌ | apiVerifyContact | `apiVerifyContact` | `NOT FOUND` |
| ❌ | apiVerifyGroupMember | `/_verify code #\(groupId) \(groupMemberId) \(conne...` | `NOT FOUND` |
| ❌ | apiVerifyGroupMember | `/_verify code #\(groupId) \(groupMemberId)` | `NOT FOUND` |
| ❌ | apiVerifyGroupMember | `apiVerifyGroupMember` | `NOT FOUND` |
| ❌ | apiVerifyToken | `/_ntf verify \(token.cmdString) \(nonce) \(code)` | `NOT FOUND` |
| ❌ | apiVerifyToken | `apiVerifyToken` | `NOT FOUND` |
| ❌ | around | `around=\(chatItemId) count=\(count)` | `NOT FOUND` |
| ❌ | before | `before=\(chatItemId) count=\(count)` | `NOT FOUND` |
| ❌ | cancelFile | `/fcancel \(fileId)` | `NOT FOUND` |
| ❌ | cancelFile | `cancelFile` | `NOT FOUND` |
| ❌ | chatContentTypes | `content types: \(String(describing: types))` | `NOT FOUND` |
| ❌ | chatErrors | `chatErrors: \(String(describing: chatErrors))` | `NOT FOUND` |
| ❌ | chatHelp | `helpSection: \(section.prefix(100))` | `NOT FOUND` |
| ❌ | checkChatRunning | `/_check running` | `NOT FOUND` |
| ❌ | checkChatRunning | `checkChatRunning` | `NOT FOUND` |
| ❌ | confirmRemoteCtrl | `/confirm remote ctrl \(rcId)` | `NOT FOUND` |
| ❌ | confirmRemoteCtrl | `confirmRemoteCtrl` | `NOT FOUND` |
| ❌ | connNtfMessages | `receivedMsgs: \(String(describing: receivedMsgs))` | `NOT FOUND` |
| ❌ | connectRemoteCtrl | `/connect remote ctrl \(xrcpInv)` | `NOT FOUND` |
| ❌ | connectRemoteCtrl | `connectRemoteCtrl` | `NOT FOUND` |
| ❌ | connectionInactive | `connectionEntity: \(String(describing: connectionE...` | `NOT FOUND` |
| ❌ | connectionsDiff | `userIds: \(String(describing: userIds))\nconnIds: ...` | `NOT FOUND` |
| ❌ | createActiveUser | `createActiveUser` | `NOT FOUND` |
| ❌ | customChatEvent | `\(String(describing: user_))\nresponse: \(response...` | `NOT FOUND` |
| ❌ | deleteRemoteCtrl | `/delete remote ctrl \(rcId)` | `NOT FOUND` |
| ❌ | deleteRemoteCtrl | `deleteRemoteCtrl` | `NOT FOUND` |
| ❌ | getAgentServersSummary | `/get servers summary \(userId)` | `NOT FOUND` |
| ❌ | getAgentServersSummary | `getAgentServersSummary` | `NOT FOUND` |
| ❌ | getAgentSubsTotal | `/get subs total \(userId)` | `NOT FOUND` |
| ❌ | getAgentSubsTotal | `getAgentSubsTotal` | `NOT FOUND` |
| ❌ | hostConnected | `protocol: \(protocol_)\ntransportHost: \(transport...` | `NOT FOUND` |
| ❌ | hostDisconnected | `protocol: \(protocol_)\ntransportHost: \(transport...` | `NOT FOUND` |
| ❌ | initial | `initial=\(count)` | `NOT FOUND` |
| ❌ | instant | `bolt` | `NOT FOUND` |
| ❌ | last | `count=\(count)` | `NOT FOUND` |
| ❌ | listRemoteCtrls | `/list remote ctrls` | `NOT FOUND` |
| ❌ | listRemoteCtrls | `listRemoteCtrls` | `NOT FOUND` |
| ❌ | listUsers | `/users` | `NOT FOUND` |
| ❌ | listUsers | `listUsers` | `NOT FOUND` |
| ❌ | newRemoteHost | `remoteHost: \(String(describing: remoteHost))` | `NOT FOUND` |
| ❌ | ntfToken | `token: \(token)\nstatus: \(status.rawValue)\nntfMo...` | `NOT FOUND` |
| ❌ | off | `arrow.clockwise` | `NOT FOUND` |
| ❌ | periodic | `timer` | `NOT FOUND` |
| ❌ | receiveFile | `/freceive \(fileId)\(onOffParam(` | `NOT FOUND` |
| ❌ | receiveFile | `receiveFile` | `NOT FOUND` |
| ❌ | reconnectAllServers | `/reconnect` | `NOT FOUND` |
| ❌ | reconnectAllServers | `reconnectAllServers` | `NOT FOUND` |
| ❌ | reconnectServer | `/reconnect \(userId) \(smpServer)` | `NOT FOUND` |
| ❌ | reconnectServer | `reconnectServer` | `NOT FOUND` |
| ❌ | remoteCtrlConnected | `\(String(describing: remoteCtrl))\ncompression: \(...` | `NOT FOUND` |
| ❌ | remoteCtrlConnecting | `remoteCtrl_:\n\(String(describing: remoteCtrl_))\n...` | `NOT FOUND` |
| ❌ | remoteCtrlFound | `remoteCtrl:\n\(String(describing: remoteCtrl))\nct...` | `NOT FOUND` |
| ❌ | remoteCtrlSessionCode | `remoteCtrl_:\n\(String(describing: remoteCtrl_))\n...` | `NOT FOUND` |
| ❌ | remoteCtrlStopped | `remoteCtrl_: \(String(describing: remoteCtrl_))\nr...` | `NOT FOUND` |
| ❌ | remoteHostConnected | `remoteHost: \(String(describing: remoteHost))\ncom...` | `NOT FOUND` |
| ❌ | remoteHostSessionCode | `remoteHost_: \(String(describing: remoteHost_))\ns...` | `NOT FOUND` |
| ❌ | remoteHostStopped | `remoteHostId_: \(String(describing: remoteHostId_)...` | `NOT FOUND` |
| ❌ | resetAgentServersStats | `/reset servers stats` | `NOT FOUND` |
| ❌ | resetAgentServersStats | `resetAgentServersStats` | `NOT FOUND` |
| ❌ | serverOperatorConditions | `conditions: \(String(describing: conditions))` | `NOT FOUND` |
| ❌ | serviceReplySent | `connectionId: \(connectionId)` | `NOT FOUND` |
| ❌ | serviceSubStatus | `server: \(server)\nserviceSubEvent: \(String(descr...` | `NOT FOUND` |
| ❌ | setAllContactReceipts | `/set receipts all \(onOff(enable))` | `NOT FOUND` |
| ❌ | setAllContactReceipts | `setAllContactReceipts` | `NOT FOUND` |
| ❌ | setFileToReceive | `/_set_file_to_receive \(fileId)\(onOffParam(` | `NOT FOUND` |
| ❌ | setFileToReceive | `setFileToReceive` | `NOT FOUND` |
| ❌ | setLocalDeviceName | `/set device name \(displayName)` | `NOT FOUND` |
| ❌ | setLocalDeviceName | `setLocalDeviceName` | `NOT FOUND` |
| ❌ | showActiveUser | `/u` | `NOT FOUND` |
| ❌ | showActiveUser | `showActiveUser` | `NOT FOUND` |
| ❌ | showVersion | `/version` | `NOT FOUND` |
| ❌ | showVersion | `showVersion` | `NOT FOUND` |
| ❌ | startChat | `/_start main=\(onOff(mainApp)) snd_files=\(onOff(e...` | `NOT FOUND` |
| ❌ | startChat | `startChat` | `NOT FOUND` |
| ❌ | stopRemoteCtrl | `/stop remote ctrl` | `NOT FOUND` |
| ❌ | stopRemoteCtrl | `stopRemoteCtrl` | `NOT FOUND` |
| ❌ | string | `console command` | `NOT FOUND` |
| ❌ | subscriptionStatus | `server: \(server)\nsubscriptionStatus: \(String(de...` | `NOT FOUND` |
| ❌ | testStorageEncryption | `/db test key \(key)` | `NOT FOUND` |
| ❌ | testStorageEncryption | `testStorageEncryption` | `NOT FOUND` |
| ❌ | timedAction | `action: \(action)\ndurationMilliseconds: \(duratio...` | `NOT FOUND` |
| ❌ | usageConditions | `usageConditions: \(String(describing: usageConditi...` | `NOT FOUND` |
| ❌ | verifyRemoteCtrlSession | `/verify remote ctrl \(sessCode)` | `NOT FOUND` |
| ❌ | verifyRemoteCtrlSession | `verifyRemoteCtrlSession` | `NOT FOUND` |
| ❌ | versionInfo | `\(String(describing: versionInfo))\n\nchat migrati...` | `NOT FOUND` |