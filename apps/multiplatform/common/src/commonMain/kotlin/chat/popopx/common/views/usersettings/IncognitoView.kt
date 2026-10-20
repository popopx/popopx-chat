package chat.popopx.common.views.usersettings

import SectionBottomSpacer
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import dev.icerock.moko.resources.compose.stringResource
import androidx.compose.ui.unit.dp
import chat.popopx.common.platform.ColumnWithScrollBar
import chat.popopx.common.ui.theme.DEFAULT_PADDING
import chat.popopx.common.views.helpers.AppBarTitle
import chat.popopx.common.views.helpers.generalGetString
import chat.popopx.common.views.onboarding.ReadableTextWithLink
import chat.popopx.res.*

@Composable
fun IncognitoView() {
  IncognitoLayout()
}

@Composable
fun IncognitoLayout() {
  ColumnWithScrollBar {
    AppBarTitle(stringResource(MR.strings.settings_section_title_incognito))
    Column(
      Modifier
        .padding(horizontal = DEFAULT_PADDING),
      verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
      Text(generalGetString(MR.strings.incognito_info_protects))
      Text(generalGetString(MR.strings.incognito_info_allows))
      Text(generalGetString(MR.strings.incognito_info_share))
      ReadableTextWithLink(MR.strings.read_more_in_user_guide_with_link, "https://popopxchat.com/docs/guide/chat-profiles.html#incognito-mode")
      SectionBottomSpacer()
    }
  }
}
