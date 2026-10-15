package chat.popopx.common.helpers

import android.content.*
import android.net.Uri
import android.provider.Settings
import chat.popopx.common.platform.*
import chat.popopx.common.views.helpers.AlertManager
import chat.popopx.common.views.helpers.generalGetString
import chat.popopx.res.*

fun Context.openAppSettingsInSystem() {
  Intent().apply {
    action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
    data = Uri.parse("package:${androidAppContext.packageName}")
    try {
      startActivity(this)
    } catch (e: ActivityNotFoundException) {
      Log.e(TAG, e.stackTraceToString())
    }
  }
}

fun Context.showAllowPermissionInSettingsAlert(action: () -> Unit = ::openAppSettingsInSystem) {
  AlertManager.shared.showAlertMsg(
    title =  generalGetString(MR.strings.permissions_grant_in_settings),
    text = generalGetString(MR.strings.permissions_find_in_settings_and_grant),
    confirmText = generalGetString(MR.strings.permissions_open_settings),
    onConfirm = action,
  )
}
