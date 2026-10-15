package chat.popopx.common.platform

expect fun getWakeLock(timeout: Long): (() -> Unit)
