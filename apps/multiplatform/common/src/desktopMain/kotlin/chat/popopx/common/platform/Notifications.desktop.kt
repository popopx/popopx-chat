package chat.popopx.common.platform

import chat.popopx.common.popopxWindowState

actual fun allowedToShowNotification(): Boolean = !popopxWindowState.windowFocused.value
