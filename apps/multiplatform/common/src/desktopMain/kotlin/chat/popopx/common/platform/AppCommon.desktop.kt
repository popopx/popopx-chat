package chat.popopx.common.platform

import chat.popopx.common.model.*
import chat.popopx.common.popopxWindowState
import chat.popopx.common.views.call.RcvCallInvitation
import chat.popopx.common.views.database.deleteOldChatArchive
import chat.popopx.common.views.helpers.*
import java.util.*
import chat.popopx.res.*
import java.io.File

actual val appPlatform = AppPlatform.DESKTOP

actual val deviceName = generalGetString(MR.strings.desktop_device)

actual fun isAppVisibleAndFocused() = popopxWindowState.windowFocused.value

@Suppress("ConstantLocale")
val defaultLocale: Locale = Locale.getDefault()

fun initApp() {
  ntfManager = object : NtfManager() {
    override fun notifyCallInvitation(invitation: RcvCallInvitation): Boolean = chat.popopx.common.model.NtfManager.notifyCallInvitation(invitation)
    override fun hasNotificationsForChat(chatId: String): Boolean = chat.popopx.common.model.NtfManager.hasNotificationsForChat(chatId)
    override fun cancelNotificationsForChat(chatId: String) = chat.popopx.common.model.NtfManager.cancelNotificationsForChat(chatId)
    override fun cancelNotificationsForUser(userId: Long) = chat.popopx.common.model.NtfManager.cancelNotificationsForUser(userId)
    override fun displayNotification(user: UserLike, chatId: String, displayName: String, msgText: String, image: String?, actions: List<Pair<NotificationAction, () -> Unit>>) = chat.popopx.common.model.NtfManager.displayNotification(user, chatId, displayName, msgText, image, actions)
    override fun androidCreateNtfChannelsMaybeShowAlert() {}
    override fun cancelCallNotification() {}
    override fun cancelAllNotifications() = chat.popopx.common.model.NtfManager.cancelAllNotifications()
    override fun showMessage(title: String, text: String) = chat.popopx.common.model.NtfManager.showMessage(title, text)
  }
  applyAppLocale()
  deleteOldChatArchive()
  if (DatabaseUtils.ksSelfDestructPassword.get() == null) {
    initChatControllerOnStart()
  }
  // LALAL
  //testCrypto()
}

//fun discoverVlcLibs(path: String) {
//  uk.co.caprica.vlcj.binding.LibC.INSTANCE.setenv("VLC_PLUGIN_PATH", path, 1)
//}

private fun applyAppLocale() {
  val lang = ChatController.appPrefs.appLanguage.get()
  if (lang == null || lang == Locale.getDefault().language) return
  Locale.setDefault(Locale.forLanguageTag(lang))
}
