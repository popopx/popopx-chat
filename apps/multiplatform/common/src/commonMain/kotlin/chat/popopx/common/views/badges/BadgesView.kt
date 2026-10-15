package chat.popopx.common.views.badges

import androidx.compose.animation.*
import androidx.compose.runtime.Composable
import chat.popopx.common.model.BadgeModel
import chat.popopx.common.model.BadgeState
import chat.popopx.common.platform.chatModel
import chat.popopx.common.views.helpers.ModalManager
import chat.popopx.common.views.helpers.ModalView

@OptIn(ExperimentalAnimationApi::class)
@Composable
fun BadgesView(modalManager: ModalManager, close: () -> Unit) {
  val shownBadge: BadgeState? = run {
    if (!BadgeModel.isCurrent(chatModel.remoteHostId(), chatModel.currentUser.value?.userId)) return@run null
    val badgeState = BadgeModel.badgeState.value
    if (badgeState != null && badgeState.shown) badgeState else null
  }

  // the card look is a modal setting, so the modal is composed here to follow the screen shown
  ModalView(close, cardScreen = shownBadge != null) {
    AnimatedContent(targetState = shownBadge, transitionSpec = { fadeIn() with fadeOut() }, contentKey = { it != null }) { badgeState ->
      if (badgeState != null) {
        BadgesYourBadgeView(badgeState, modalManager)
      } else {
        BadgesSupportPopopxView(modalManager)
      }
    }
  }
}

// ModalManager.end, not start: every caller is in the chat, which on desktop is the right pane
fun openBadgesView() {
  ModalManager.end.showCustomModal { close -> BadgesView(ModalManager.end, close) }
}
