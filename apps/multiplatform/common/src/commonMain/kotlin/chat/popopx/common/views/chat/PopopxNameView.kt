package chat.popopx.common.views.chat

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.*
import androidx.compose.ui.unit.dp
import dev.icerock.moko.resources.ImageResource
import chat.popopx.common.model.*
import chat.popopx.common.platform.*
import chat.popopx.common.ui.theme.DEFAULT_PADDING_HALF
import chat.popopx.common.views.helpers.*
import chat.popopx.res.*
import dev.icerock.moko.resources.compose.painterResource
import dev.icerock.moko.resources.compose.stringResource
import kotlinx.coroutines.*

// Renders a contact's / channel's POPOPX name with its 3-state verification indicator.
// `verification`: null = not attempted, false = failed, true = verified.
// `verify` runs the verify API, updates the model and returns (newVerification, failureReason);
// null on network error. With `autoVerify`, it runs once on open when state is null.
@Composable
fun PopopxNameView(
  popopxName: String,
  verified: Boolean?,
  verifiable: Boolean = true,
  verify: suspend () -> Pair<Boolean?, String?>?
) {
  val scope = rememberCoroutineScope()
  val inFlight = remember { mutableStateOf(false) }
  val showSpinner = remember { mutableStateOf(false) }

  fun runVerify(manual: Boolean) {
    if (inFlight.value) return
    inFlight.value = true
    scope.launch {
      // delay the spinner so a fast result on open doesn't flash it
      val spinner = launch { delay(300); if (inFlight.value) showSpinner.value = true }
      val res = try {
        verify()
      } catch (e: Exception) {
        Log.e(TAG, "verify PopopxName: ${e.stackTraceToString()}")
        null
      }
      spinner.cancel()
      inFlight.value = false
      showSpinner.value = false
      if (res != null) {
        val (newV, reason) = res
        // show the reason on a manual run, or on an inconclusive auto run (state stayed null)
        if (reason != null && (manual || newV == null)) {
          AlertManager.shared.showAlertMsg(generalGetString(MR.strings.popopx_name_not_verified), reason)
        }
      }
    }
  }

  LaunchedEffect(Unit) {
    if (verifiable && chatModel.controller.appPrefs.privacyVerifyPopopxNames.get() && verified == null) runVerify(manual = false)
  }

  val clipboard = LocalClipboardManager.current
  val nameStyle = MaterialTheme.typography.body2.copy(
    color = if (verified == true) MaterialTheme.colors.primary else MaterialTheme.colors.secondary
  )
  Row(
    verticalAlignment = Alignment.CenterVertically,
    horizontalArrangement = Arrangement.spacedBy(6.dp),
    modifier = Modifier.padding(top = DEFAULT_PADDING_HALF)
  ) {
    when {
      showSpinner.value -> {
        Text(popopxName, style = nameStyle)
        CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp, color = MaterialTheme.colors.secondary)
      }
      verified == true ->
        PopopxNameWithIcon(popopxName, nameStyle, MR.images.ic_check_filled, MaterialTheme.colors.primary) {
          clipboard.setText(AnnotatedString(popopxName))
          showToast(generalGetString(MR.strings.copied))
        }
      !verifiable -> Text(popopxName, style = nameStyle)
      verified == false ->
        PopopxNameWithIcon(popopxName, nameStyle, MR.images.ic_close, Color.Red) { runVerify(manual = true) }
      else -> {
        Text(popopxName, style = nameStyle)
        Text(
          stringResource(MR.strings.verify_popopx_name_action),
          color = MaterialTheme.colors.primary,
          modifier = Modifier.clickable { runVerify(manual = true) }
        )
      }
    }
  }
}

// The check/cross drawable is centered in its box with ~27% padding top and bottom, so its glyph bottom sits at
// ~73% of the box height. Align that line with the text baseline so the glyph rests on the baseline; the box is
// sized so the visible glyph is about the name's cap height. Only the icon is tinted, never the name.
@Composable
private fun PopopxNameWithIcon(name: String, style: TextStyle, icon: ImageResource, tint: Color, onClick: () -> Unit) {
  Row(
    horizontalArrangement = Arrangement.spacedBy(2.dp),
    modifier = Modifier.clickable { onClick() }
  ) {
    Text(name, Modifier.alignByBaseline(), style = style)
    Icon(
      painterResource(icon), null,
      Modifier.size(22.dp).alignBy { it.measuredHeight * 73 / 100 },
      tint = tint
    )
  }
}

@Composable
fun ContactPopopxNameView(contact: Contact, verifiable: Boolean = true) {
  val domain = contact.profile.contactDomain
  if (domain != null && (contact.profile.contactDomainVerified != null || domain.proof != null)) {
    PopopxNameView(
      popopxName = "@${domain.domain}",
      verified = contact.profile.contactDomainVerified,
      verifiable = verifiable,
      verify = {
        val rhId = chatModel.remoteHostId()
        chatModel.controller.apiVerifyContactDomain(rhId, contact.contactId)?.let { (ct, reason) ->
          chatModel.chatsContext.updateContact(rhId, ct)
          ct.profile.contactDomainVerified to reason
        }
      }
    )
  }
}

@Composable
fun GroupPopopxNameView(groupInfo: GroupInfo, verifiable: Boolean = true) {
  if (groupInfo.businessChat == null) {
    val access = groupInfo.groupProfile.publicGroup?.publicGroupAccess
    val domain = access?.groupDomainClaim?.shortName
    if (domain != null && (groupInfo.groupDomainVerified != null || access.groupDomainClaim?.proof != null)) {
      PopopxNameView(
        popopxName = "#${domain}",
        verified = groupInfo.groupDomainVerified,
        verifiable = verifiable,
        verify = {
          val rhId = chatModel.remoteHostId()
          chatModel.controller.apiVerifyGroupDomain(rhId, groupInfo.groupId)?.let { (gInfo, reason) ->
            chatModel.chatsContext.updateGroup(rhId, gInfo)
            gInfo.groupDomainVerified to reason
          }
        }
      )
    }
  } else {
    val businessClaim = groupInfo.businessChat?.businessDomain
    if (businessClaim != null && (groupInfo.groupDomainVerified != null || businessClaim.proof != null)) {
      // A business presents as a contact, so the name retains its .popopx suffix; it cannot be re-verified.
      PopopxNameView(
        popopxName = "@${businessClaim.domain}",
        verified = groupInfo.groupDomainVerified,
        verifiable = false,
        verify = { null }
      )
    }
  }
}
