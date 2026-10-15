package chat.popopx.common.views.usersettings.networkAndServers

import androidx.compose.runtime.Composable
import chat.popopx.common.model.UserServer

@Composable
actual fun ScanProtocolServer(rhId: Long?, onNext: (UserServer) -> Unit) {
  ScanProtocolServerLayout(rhId, onNext)
}
