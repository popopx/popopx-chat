package chat.popopx.common.platform

const val TAG = "POPOPX"

enum class LogLevel {
  DEBUG, INFO, WARNING, ERROR
}

expect object Log {
  fun d(tag: String, text: String)
  fun e(tag: String, text: String)
  fun i(tag: String, text: String)
  fun w(tag: String, text: String)
}
