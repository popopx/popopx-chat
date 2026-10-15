package chat.popopx.common.views.helpers

import androidx.compose.ui.text.AnnotatedString

interface ValueTitle <T> {
  val value: T
  val title: String
}

data class ValueTitleDesc <T> (
  override val value: T,
  override val title: String,
  val description: AnnotatedString
): ValueTitle<T>
