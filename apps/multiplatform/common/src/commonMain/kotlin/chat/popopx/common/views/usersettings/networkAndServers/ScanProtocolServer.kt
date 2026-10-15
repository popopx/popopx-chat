package chat.popopx.common.views.usersettings.networkAndServers

import androidx.compose.runtime.Composable
import dev.icerock.moko.resources.compose.stringResource
import chat.popopx.common.model.ServerAddress.Companion.parseServerAddress
import chat.popopx.common.model.UserServer
import chat.popopx.common.platform.ColumnWithScrollBar
import chat.popopx.common.views.helpers.*
import chat.popopx.common.views.newchat.QRCodeScanner
import chat.popopx.res.*

@Composable
expect fun ScanProtocolServer(rhId: Long?, onNext: (UserServer) -> Unit)

@Composable
fun ScanProtocolServerLayout(rhId: Long?, onNext: (UserServer) -> Unit) {
  ColumnWithScrollBar {
    AppBarTitle(stringResource(MR.strings.smp_servers_scan_qr))
    QRCodeScanner { text ->
      val res = parseServerAddress(text)
      if (res != null) {
        onNext(UserServer(remoteHostId = rhId, null, text, false, null, false, false))
      } else {
        AlertManager.shared.showAlertMsg(
          title = generalGetString(MR.strings.smp_servers_invalid_address),
          text = generalGetString(MR.strings.smp_servers_check_address)
        )
      }
      res != null
    }
  }
}
