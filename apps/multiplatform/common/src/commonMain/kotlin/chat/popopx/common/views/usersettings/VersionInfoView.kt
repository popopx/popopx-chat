package chat.popopx.common.views.usersettings

import SectionBottomSpacer
import SectionDividerSpaced
import SectionView
import itemHPadding
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import dev.icerock.moko.resources.compose.stringResource
import chat.popopx.common.BuildConfigCommon
import chat.popopx.common.model.ChatModel
import chat.popopx.common.model.CoreVersionInfo
import chat.popopx.common.platform.ColumnWithScrollBar
import chat.popopx.common.platform.appPlatform
import chat.popopx.common.platform.chatModel
import chat.popopx.common.ui.theme.DEFAULT_PADDING_HALF
import chat.popopx.common.views.helpers.AppBarTitle
import chat.popopx.res.*

@Composable
fun VersionInfoView(
  showSettingsModal: (@Composable (ChatModel) -> Unit) -> (() -> Unit),
  withAuth: (title: String, desc: String, block: () -> Unit) -> Unit,
) {
  val versionInfo = remember { mutableStateOf<CoreVersionInfo?>(null) }
  LaunchedEffect(Unit) {
    versionInfo.value = chatModel.controller.apiGetVersion()
  }
  ColumnWithScrollBar {
    AppBarTitle(stringResource(MR.strings.app_version_title))
    SectionView {
      Column(Modifier.padding(horizontal = itemHPadding, vertical = DEFAULT_PADDING_HALF)) {
        if (appPlatform.isAndroid) {
          Text(String.format(stringResource(MR.strings.app_version_name), BuildConfigCommon.ANDROID_VERSION_NAME))
          Text(String.format(stringResource(MR.strings.app_version_code), BuildConfigCommon.ANDROID_VERSION_CODE))
        } else {
          Text(String.format(stringResource(MR.strings.app_version_name), BuildConfigCommon.DESKTOP_VERSION_NAME))
          Text(String.format(stringResource(MR.strings.app_version_code), BuildConfigCommon.DESKTOP_VERSION_CODE))
        }
        versionInfo.value?.let { info ->
          Text(String.format(stringResource(MR.strings.core_version), info.version))
          val popopxmqCommit = if (info.popopxmqCommit.length >= 7) info.popopxmqCommit.substring(startIndex = 0, endIndex = 7) else info.popopxmqCommit
          Text(String.format(stringResource(MR.strings.core_popopxmq_version), info.popopxmqVersion, popopxmqCommit))
        }
      }
    }
    SectionDividerSpaced()

    AdvancedSettingsAppSection(showSettingsModal, withAuth)
    SectionBottomSpacer()
  }
}
