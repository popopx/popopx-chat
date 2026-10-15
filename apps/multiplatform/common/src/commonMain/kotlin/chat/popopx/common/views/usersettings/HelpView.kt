package chat.popopx.common.views.usersettings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import dev.icerock.moko.resources.compose.stringResource
import androidx.compose.desktop.ui.tooling.preview.Preview
import chat.popopx.common.platform.ColumnWithScrollBar
import chat.popopx.common.ui.theme.DEFAULT_PADDING
import chat.popopx.common.ui.theme.POPOPXTheme
import chat.popopx.common.views.chatlist.ChatHelpView
import chat.popopx.common.views.helpers.AppBarTitle
import chat.popopx.res.*

@Composable
fun HelpView(userDisplayName: String) {
  HelpLayout(userDisplayName)
}

@Composable
fun HelpLayout(userDisplayName: String) {
  ColumnWithScrollBar(Modifier.padding(horizontal = DEFAULT_PADDING)){
    AppBarTitle(String.format(stringResource(MR.strings.personal_welcome), userDisplayName), withPadding = false)
    ChatHelpView()
  }
}

@Preview/*(
  uiMode = Configuration.UI_MODE_NIGHT_YES,
  showBackground = true,
  name = "Dark Mode"
)*/
@Composable
fun PreviewHelpView() {
  POPOPXTheme {
    HelpLayout("Alice")
  }
}
