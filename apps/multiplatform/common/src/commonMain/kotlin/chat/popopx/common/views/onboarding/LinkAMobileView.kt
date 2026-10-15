package chat.popopx.common.views.onboarding

import SectionTextFooter
import SectionView
import androidx.compose.foundation.layout.*
import androidx.compose.material.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import chat.popopx.common.model.ChatController.appPrefs
import chat.popopx.common.model.ChatModel
import chat.popopx.common.platform.chatModel
import chat.popopx.common.ui.theme.DEFAULT_PADDING
import chat.popopx.common.views.helpers.*
import chat.popopx.common.views.remote.AddingMobileDevice
import chat.popopx.common.views.remote.DeviceNameField
import chat.popopx.common.views.usersettings.PreferenceToggle
import chat.popopx.res.*
import dev.icerock.moko.resources.compose.stringResource

@Composable
fun LinkAMobile() {
  val connecting = rememberSaveable { mutableStateOf(false) }
  val deviceName = chatModel.controller.appPrefs.deviceNameForRemoteAccess
  var deviceNameInQrCode by remember { mutableStateOf(chatModel.controller.appPrefs.deviceNameForRemoteAccess.get()) }
  val staleQrCode = remember { mutableStateOf(false) }

  LinkAMobileLayout(
    deviceName = remember { deviceName.state },
    connecting,
    staleQrCode,
    updateDeviceName = {
      withBGApi {
        if (it != "" && it != deviceName.get()) {
          chatModel.controller.setLocalDeviceName(it)
          deviceName.set(it)
          staleQrCode.value = deviceName.get() != deviceNameInQrCode
        }
      }
    }
  )
  KeyChangeEffect(staleQrCode.value) {
    if (!staleQrCode.value) {
      deviceNameInQrCode = deviceName.get()
    }
  }
}

@Composable
private fun LinkAMobileLayout(
  deviceName: State<String?>,
  connecting: MutableState<Boolean>,
  staleQrCode: MutableState<Boolean>,
  updateDeviceName: (String) -> Unit,
) {
  ModalView({ appPrefs.onboardingStage.set(OnboardingStage.Step1_POPOPXInfo) }) {
    Column(Modifier.fillMaxSize().padding(top = AppBarHeight * fontSizeSqrtMultiplier)) {
      Box(Modifier.align(Alignment.CenterHorizontally)) {
        AppBarTitle(stringResource(if (remember { chatModel.remoteHosts }.isEmpty()) MR.strings.link_a_mobile else MR.strings.linked_mobiles), overrideTitleColor = MaterialTheme.colors.onBackground)
      }
      Row(Modifier.weight(1f).padding(horizontal = DEFAULT_PADDING * 2), verticalAlignment = Alignment.CenterVertically) {
        Column(
          Modifier.weight(0.3f),
          verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
          SectionView(generalGetString(MR.strings.this_device_name)) {
            DeviceNameField(deviceName.value ?: "") { updateDeviceName(it) }
            SectionTextFooter(generalGetString(MR.strings.this_device_name_shared_with_mobile))
            PreferenceToggle(stringResource(MR.strings.multicast_discoverable_via_local_network), checked = remember { ChatModel.controller.appPrefs.offerRemoteMulticast.state }.value) {
              ChatModel.controller.appPrefs.offerRemoteMulticast.set(it)
            }
          }
        }
        Box(Modifier.weight(0.7f)) {
          AddingMobileDevice(false, staleQrCode, connecting) {
            // currentRemoteHost will be set instantly but remoteHosts may be delayed
            if (chatModel.remoteHosts.isEmpty() && chatModel.currentRemoteHost.value == null) {
              chatModel.controller.appPrefs.onboardingStage.set(OnboardingStage.Step1_POPOPXInfo)
            } else {
              chatModel.controller.appPrefs.onboardingStage.set(OnboardingStage.OnboardingComplete)
            }
          }
        }
      }
    }
  }
}
