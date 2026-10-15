package chat.popopx.common.platform

actual fun allowedToShowNotification(): Boolean = !isAppOnForeground
