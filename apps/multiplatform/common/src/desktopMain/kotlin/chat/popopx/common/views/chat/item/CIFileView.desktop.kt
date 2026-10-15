package chat.popopx.common.views.chat.item

import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import chat.popopx.common.model.CryptoFile
import java.net.URI

@Composable
actual fun SaveOrOpenFileMenu(
  showMenu: MutableState<Boolean>,
  encrypted: Boolean,
  ext: String?,
  encryptedUri: URI,
  fileSource: CryptoFile,
  saveFile: () -> Unit
) {

}
