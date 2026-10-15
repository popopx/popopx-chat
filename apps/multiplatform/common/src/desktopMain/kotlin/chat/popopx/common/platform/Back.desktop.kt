package chat.popopx.common.platform

import androidx.compose.runtime.*
import chat.popopx.common.popopxWindowState

@Composable
actual fun BackHandler(enabled: Boolean, onBack: () -> Unit) {
  DisposableEffect(enabled) {
    if (enabled) popopxWindowState.backstack.add(onBack)
    onDispose {
      popopxWindowState.backstack.remove(onBack)
    }
  }
}
