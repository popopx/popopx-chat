package chat.popopx.common.platform

actual fun getWakeLock(timeout: Long): (() -> Unit) = {}
