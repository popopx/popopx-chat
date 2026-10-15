package chat.popopx.common

import androidx.compose.desktop.ui.tooling.preview.Preview
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.awt.ComposeWindow
import androidx.compose.ui.input.key.*
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.*
import chat.popopx.common.model.*
import chat.popopx.common.platform.*
import chat.popopx.common.ui.theme.DEFAULT_START_MODAL_WIDTH
import chat.popopx.common.ui.theme.POPOPXTheme
import chat.popopx.common.views.TerminalView
import chat.popopx.common.views.helpers.*
import chat.popopx.res.*
import dev.icerock.moko.resources.compose.painterResource
import dev.icerock.moko.resources.compose.stringResource
import kotlinx.coroutines.*
import java.awt.Frame
import java.awt.event.WindowEvent
import java.awt.event.WindowFocusListener
import java.io.File
import kotlin.system.exitProcess

val popopxWindowState = PopopxWindowState()

fun showApp() {
  // Probe SystemTray off the EDT — the lazy's first read would otherwise block the
  // EDT during composition; JDK-8322750's GNOME detection forks a subprocess.
  trayIsAvailable
  while (true) {
    val closedByError = mutableStateOf(false)
    application(exitProcessOnExit = false) {
      CompositionLocalProvider(
        LocalWindowExceptionHandlerFactory provides WindowExceptionHandlerFactory { window ->
          WindowExceptionHandler { e ->
            AlertManager.shared.showAlertMsg(
              title = generalGetString(MR.strings.app_was_crashed),
              text = e.stackTraceToString(),
              shareText = true
            )
            Log.e(TAG, "App crashed, thread name: " + Thread.currentThread().name + ", exception: " + e.stackTraceToString())
            // Must precede dispatchEvent — handleCloseRequest reads this flag.
            closedByError.value = true
            window.dispatchEvent(WindowEvent(window, WindowEvent.WINDOW_CLOSING))
            includeMoreFailedComposables()
            // If the left side of screen has open modal, it's probably caused the crash
            if (ModalManager.start.hasModalsOpen()) {
              ModalManager.start.closeModal()
            } else if (ModalManager.center.hasModalsOpen() || ModalManager.end.hasModalsOpen()) {
              ModalManager.center.closeModal()
              ModalManager.end.closeModal()
              // Better to not close fullscreen since it can contain passcode
            } else {
              // The last possible cause that can be closed
              withApi {
                withContext(Dispatchers.Main) {
                  chatModel.chatId.value = null
                  chatModel.chatsContext.chatItems.clearAndNotify()
                }
                withContext(Dispatchers.Main) {
                  chatModel.secondaryChatsContext.value = null
                }
              }
            }
            chatModel.activeCall.value?.let {
              withBGApi {
                chatModel.callManager.endCall(it)
              }
            }
          }
        }
      ) {
        PopopxTray()
        AppWindow(closedByError)
      }
    }
    if (!closedByError.value) break
  }
  exitProcess(0)
}

@Composable
private fun ApplicationScope.AppWindow(closedByError: MutableState<Boolean>) {
  // Creates file if not exists; comes with proper defaults
  val state = getStoredWindowState()
  val windowState: WindowState = rememberWindowState(
    placement = WindowPlacement.Floating,
    width = state.width.dp,
    height = state.height.dp,
    position = WindowPosition(state.x.dp, state.y.dp)
  )

  val storingJob: MutableState<Job> = remember { mutableStateOf(Job()) }
  LaunchedEffect(
    windowState.position.x.value,
    windowState.position.y.value,
    windowState.size.width.value,
    windowState.size.height.value
  ) {
    storingJob.value.cancel()
    storingJob.value = launch {
      delay(1000L)
      storeWindowState(
        WindowPositionSize(
          x = windowState.position.x.value.toInt(),
          y = windowState.position.y.value.toInt(),
          width = windowState.size.width.value.toInt(),
          height = windowState.size.height.value.toInt()
        )
      )
    }
  }

  popopxWindowState.windowState = windowState
  // Reload all strings in all @Composable's after language change at runtime
  if (remember { ChatController.appPrefs.appLanguage.state }.value != "") {
    Window(state = windowState, visible = popopxWindowState.windowVisible.value, icon = painterResource(MR.images.ic_popopx), onCloseRequest = { handleCloseRequest(closedByError) }, onKeyEvent = {
      if (it.key == Key.Escape && it.type == KeyEventType.KeyUp) {
        popopxWindowState.backstack.lastOrNull()?.invoke() != null
      } else {
        false
      }
    }, title = "POPOPX") {
//      val hardwareAccelerationDisabled = remember { listOf(GraphicsApi.SOFTWARE_FAST, GraphicsApi.SOFTWARE_COMPAT, GraphicsApi.UNKNOWN).contains(window.renderApi) }
      popopxWindowState.window = window
      AppScreen()
      if (popopxWindowState.openDialog.isAwaiting) {
        FileDialogChooser(
          title = "POPOPX",
          isLoad = true,
          params = popopxWindowState.openDialog.params,
          onResult = {
            popopxWindowState.openDialog.onResult(it.firstOrNull())
          }
        )
      }

      if (popopxWindowState.openMultipleDialog.isAwaiting) {
        FileDialogChooser(
          title = "POPOPX",
          isLoad = true,
          params = popopxWindowState.openMultipleDialog.params,
          onResult = {
            popopxWindowState.openMultipleDialog.onResult(it)
          }
        )
      }

      if (popopxWindowState.saveDialog.isAwaiting) {
        FileDialogChooser(
          title = "POPOPX",
          isLoad = false,
          params = popopxWindowState.saveDialog.params,
          onResult = { popopxWindowState.saveDialog.onResult(it.firstOrNull()) }
        )
      }
      val toasts = remember { popopxWindowState.toasts }
      val toast = toasts.firstOrNull()
      if (toast != null) {
        POPOPXTheme {
          Box(Modifier.fillMaxSize().padding(bottom = 20.dp), contentAlignment = Alignment.BottomCenter) {
            Text(
              escapedHtmlToAnnotatedString(toast.first, LocalDensity.current),
              Modifier.background(MaterialTheme.colors.primary, RoundedCornerShape(100)).padding(vertical = 5.dp, horizontal = 10.dp),
              color = MaterialTheme.colors.onPrimary,
              style = MaterialTheme.typography.body1
            )
          }
        }
        // Shows toast in insertion order with preferred delay per toast. New one will be shown once previous one expires
        LaunchedEffect(toast, toasts.size) {
          delay(toast.second)
          popopxWindowState.toasts.removeFirstOrNull()
        }
      }
      var windowFocused by remember { popopxWindowState.windowFocused }
      val showCallView = ChatModel.showCallView.value
      LaunchedEffect(windowFocused, showCallView) {
        val delay = ChatController.appPrefs.laLockDelay.get()
        if (!windowFocused && !showCallView && ChatModel.showAuthScreen.value && delay > 0) {
          delay(delay * 1000L)
          // Trigger auth state check when delay ends (and if it ends)
          AppLock.recheckAuthState()
        }
      }
      LaunchedEffect(Unit) {
        window.addWindowFocusListener(object: WindowFocusListener {
          override fun windowGainedFocus(p0: WindowEvent?) {
            windowFocused = true
            AppLock.recheckAuthState()
          }

          override fun windowLostFocus(p0: WindowEvent?) {
            windowFocused = false
            AppLock.appWasHidden()
          }
        })
      }
    }
  }
  // Reload all strings in all @Composable's after language change at runtime
  if (remember { ChatController.appPrefs.developerTools.state }.value && remember { ChatController.appPrefs.terminalAlwaysVisible.state }.value && remember { ChatController.appPrefs.appLanguage.state }.value != "") {
    var hiddenUntilRestart by remember { mutableStateOf(false) }
    if (!hiddenUntilRestart) {
      val cWindowState = rememberWindowState(placement = WindowPlacement.Floating, width = DEFAULT_START_MODAL_WIDTH * fontSizeSqrtMultiplier, height =
      768.dp)
      Window(state = cWindowState, onCloseRequest = { hiddenUntilRestart = true }, title = stringResource(MR.strings.chat_console)) {
        val data = remember { ModalData() }
        POPOPXTheme {
          CompositionLocalProvider(LocalAppBarHandler provides data.appBarHandler) {
            ModalView({ hiddenUntilRestart = true }) {
              TerminalView(true)
            }
            ModalManager.floatingTerminal.showInView()
            DisposableEffect(Unit) {
              onDispose {
                ModalManager.floatingTerminal.closeModals()
              }
            }
          }
        }
      }
    }
  }
}

// Not invoked for macOS Cmd+Q — that goes through AWT's default QuitHandler and
// exits the process directly. Intentional: Cmd+Q is canonical "always quit" on macOS.
private fun ApplicationScope.handleCloseRequest(closedByError: MutableState<Boolean>) {
  // Crash dispatch — bypass user-facing policy and exit; outer loop will restart.
  if (closedByError.value) {
    exitApplication()
    return
  }
  val pref = ChatController.appPrefs.closeBehavior
  when (pref.get()) {
    CloseBehavior.Quit -> exitApplication()
    CloseBehavior.MinimizeToTray -> if (trayIsAvailable && singleInstanceLock) {
      popopxWindowState.windowVisible.value = false
    } else exitApplication()
    CloseBehavior.Ask -> if (trayIsAvailable && singleInstanceLock) {
      requestCloseBehavior()
    } else {
      // Tray unavailable — Minimize is not a real option; remember Quit and exit.
      pref.set(CloseBehavior.Quit)
      exitApplication()
    }
  }
}

fun showWindow() {
  popopxWindowState.windowVisible.value = true
  popopxWindowState.window?.apply {
    // Clear ICONIFIED so a minimized window un-minimizes; preserves MAXIMIZED_BOTH
    // when set. toFront() alone does not un-minimize on any AWT platform.
    extendedState = extendedState and Frame.ICONIFIED.inv()
    toFront()
    requestFocus()
  }
}

class PopopxWindowState {
  lateinit var windowState: WindowState
  val backstack = mutableStateListOf<() -> Unit>()
  val openDialog = DialogState<File?>()
  val openMultipleDialog = DialogState<List<File>>()
  val saveDialog = DialogState<File?>()
  val toasts = mutableStateListOf<Pair<String, Long>>()
  var windowFocused = mutableStateOf(true)
  val windowVisible = mutableStateOf(true)
  var window: ComposeWindow? = null
}

data class DialogParams(
  val filename: String? = null,
  val allowMultiple: Boolean = false,
  val fileFilter: ((File?) -> Boolean)? = null,
  val fileFilterDescription: String = "",
)

class DialogState<T> {
  private var onResult: CompletableDeferred<T>? by mutableStateOf(null)
  var params = DialogParams()
  val isAwaiting get() = onResult != null

  suspend fun awaitResult(params: DialogParams = DialogParams()): T {
    onResult = CompletableDeferred()
    this.params = params
    val result = onResult!!.await()
    onResult = null
    return result
  }

  fun onResult(result: T) = onResult!!.complete(result)
}

@Preview
@Composable
fun AppPreview() {
  AppScreen()
}
