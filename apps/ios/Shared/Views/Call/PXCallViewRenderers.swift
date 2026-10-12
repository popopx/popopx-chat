//
// Created by Avently on 09.02.2023.
// Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import WebRTC
import POPOPXSwitch
import AVKit

// MARK: - POPOPX: PiP collapse/expand timing and layout configuration
private enum PXCallRendererConfig {
    /// Delay before collapsing to PiP mode
    static let pxCollapseWait: Double = 0.15
    /// Delay before expanding from PiP mode
    static let pxExpandWait: Double = 0.08
    /// Corner radius for the non-PiP overlay renderer
    static let pxFullCorner: CGFloat = 12
    /// Corner radius for the PiP overlay renderer
    static let pxPipCorner: CGFloat = 10
    /// Aspect ratio used for the overlay renderer sizing
    static let pxOverlayAspect: CGFloat = 1.28
    /// Size multiplier for PiP overlay
    static let pxPipScale: CGFloat = 0.45
    /// Size multiplier for normal overlay
    static let pxNormalScale: CGFloat = 0.35
    /// X position multiplier for PiP overlay
    static let pxPipXPos: CGFloat = 0.5
    /// X position multiplier for normal overlay
    static let pxNormalXPos: CGFloat = 0.7
    /// X inset constant for PiP overlay
    static let pxPipXOffset: CGFloat = -10
    /// X inset constant for normal overlay
    static let pxNormalXOffset: CGFloat = -15
    /// Y inset constant for PiP overlay
    static let pxPipYOffset: CGFloat = -10
    /// Y inset constant for normal overlay
    static let pxNormalYOffset: CGFloat = -88
}

struct CallViewRemote: UIViewRepresentable {
    var client: WebRTCClient
    @ObservedObject var call: Call
    @State var enablePip: (Bool) -> Void = {_ in }
    @Binding var activeCallViewIsCollapsed: Bool
    @Binding var contentMode: UIView.ContentMode
    @Binding var pipShown: Bool

    // POPOPX: set up remote video renderers with PiP support
    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        // POPOPX: primary camera renderer
        let remoteCameraRenderer = RTCMTLVideoView(frame: view.frame)
        remoteCameraRenderer.videoContentMode = contentMode
        remoteCameraRenderer.tag = 0

        // POPOPX: screen share renderer
        let screenVideo = call.peerMediaSources.screenVideo
        let remoteScreenRenderer = RTCMTLVideoView(frame: view.frame)
        remoteScreenRenderer.videoContentMode = contentMode
        remoteScreenRenderer.tag = 1
        remoteScreenRenderer.alpha = screenVideo ? 1 : 0

        context.coordinator.cameraRenderer = remoteCameraRenderer
        context.coordinator.screenRenderer = remoteScreenRenderer
        client.addRemoteCameraRenderer(remoteCameraRenderer)
        client.addRemoteScreenRenderer(remoteScreenRenderer)

        // POPOPX: layer order depends on active video source
        if screenVideo {
            addSubviewAndResize(remoteScreenRenderer, remoteCameraRenderer, into: view)
        } else {
            addSubviewAndResize(remoteCameraRenderer, remoteScreenRenderer, into: view)
        }

        if AVPictureInPictureController.isPictureInPictureSupported() {
            makeViewWithRTCRenderer(remoteCameraRenderer, remoteScreenRenderer, view, context)
        }
        return view
    }
    
    // POPOPX: configure Picture-in-Picture video call support
    func makeViewWithRTCRenderer(_ remoteCameraRenderer: RTCMTLVideoView, _ remoteScreenRenderer: RTCMTLVideoView, _ view: UIView, _ context: Context) {
        let pipRemoteCameraRenderer = pxCreatePipCameraRenderer(view: view)
        let pipRemoteScreenRenderer = pxCreatePipScreenRenderer(view: view)
        let pipVideoCallViewController = pxCreatePipViewController()
        let pipController = pxCreatePipController(view: view, viewController: pipVideoCallViewController, context: context)

        context.coordinator.pipController = pipController

        pxSetupPipTransitionHandlers(
            context: context,
            client: client,
            pipRemoteCameraRenderer: pipRemoteCameraRenderer,
            pipRemoteScreenRenderer: pipRemoteScreenRenderer,
            remoteCameraRenderer: remoteCameraRenderer,
            remoteScreenRenderer: remoteScreenRenderer
        )

        pxSetupPipRelayoutHandler(
            context: context,
            call: call,
            pipRemoteCameraRenderer: pipRemoteCameraRenderer,
            pipRemoteScreenRenderer: pipRemoteScreenRenderer,
            pipVideoCallViewController: pipVideoCallViewController
        )

        pxSetupPipEnableHandler(pipController: pipController, context: context)
    }

    // MARK: - POPOPX: PiP component creators
    private func pxCreatePipCameraRenderer(view: UIView) -> RTCMTLVideoView {
        let renderer = RTCMTLVideoView(frame: view.frame)
        renderer.videoContentMode = .scaleAspectFill
        return renderer
    }

    private func pxCreatePipScreenRenderer(view: UIView) -> RTCMTLVideoView {
        let renderer = RTCMTLVideoView(frame: view.frame)
        renderer.videoContentMode = .scaleAspectFill
        return renderer
    }

    private func pxCreatePipViewController() -> AVPictureInPictureVideoCallViewController {
        let controller = AVPictureInPictureVideoCallViewController()
        controller.preferredContentSize = CallViewRemote.pxPreferredPipSize
        return controller
    }

    private func pxCreatePipController(view: UIView, viewController: AVPictureInPictureVideoCallViewController, context: Context) -> AVPictureInPictureController {
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: view,
            contentViewController: viewController
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = context.coordinator
        return controller
    }

    // MARK: - POPOPX: PiP handler setup
    private func pxSetupPipTransitionHandlers(
        context: Context,
        client: WebRTCClient,
        pipRemoteCameraRenderer: RTCMTLVideoView,
        pipRemoteScreenRenderer: RTCMTLVideoView,
        remoteCameraRenderer: RTCMTLVideoView,
        remoteScreenRenderer: RTCMTLVideoView
    ) {
        context.coordinator.willShowHide = { show in
            pxHandlePipWillShowHide(
                show: show,
                client: client,
                pipRemoteCameraRenderer: pipRemoteCameraRenderer,
                pipRemoteScreenRenderer: pipRemoteScreenRenderer,
                context: context
            )
        }

        context.coordinator.didShowHide = { show in
            pxHandlePipDidShowHide(
                show: show,
                client: client,
                pipRemoteCameraRenderer: pipRemoteCameraRenderer,
                pipRemoteScreenRenderer: pipRemoteScreenRenderer,
                remoteCameraRenderer: remoteCameraRenderer,
                remoteScreenRenderer: remoteScreenRenderer
            )
        }
    }

    private func pxHandlePipWillShowHide(
        show: Bool,
        client: WebRTCClient,
        pipRemoteCameraRenderer: RTCMTLVideoView,
        pipRemoteScreenRenderer: RTCMTLVideoView,
        context: Context
    ) {
        if show {
            client.addRemoteCameraRenderer(pipRemoteCameraRenderer)
            client.addRemoteScreenRenderer(pipRemoteScreenRenderer)
            context.coordinator.relayout()
            DispatchQueue.main.asyncAfter(deadline: .now() + PXCallRendererConfig.pxCollapseWait) {
                activeCallViewIsCollapsed = true
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + PXCallRendererConfig.pxExpandWait) {
                activeCallViewIsCollapsed = false
            }
        }
    }

    private func pxHandlePipDidShowHide(
        show: Bool,
        client: WebRTCClient,
        pipRemoteCameraRenderer: RTCMTLVideoView,
        pipRemoteScreenRenderer: RTCMTLVideoView,
        remoteCameraRenderer: RTCMTLVideoView,
        remoteScreenRenderer: RTCMTLVideoView
    ) {
        if show {
            remoteCameraRenderer.isHidden = true
            remoteScreenRenderer.isHidden = true
        } else {
            client.removeRemoteCameraRenderer(pipRemoteCameraRenderer)
            client.removeRemoteScreenRenderer(pipRemoteScreenRenderer)
            remoteCameraRenderer.isHidden = false
            remoteScreenRenderer.isHidden = false
        }
        pipShown = show
    }

    private func pxSetupPipRelayoutHandler(
        context: Context,
        call: Call,
        pipRemoteCameraRenderer: RTCMTLVideoView,
        pipRemoteScreenRenderer: RTCMTLVideoView,
        pipVideoCallViewController: AVPictureInPictureVideoCallViewController
    ) {
        context.coordinator.relayout = {
            pxRelayoutPipRenderers(
                call: call,
                pipRemoteCameraRenderer: pipRemoteCameraRenderer,
                pipRemoteScreenRenderer: pipRemoteScreenRenderer,
                pipVideoCallViewController: pipVideoCallViewController
            )
        }
    }

    private func pxRelayoutPipRenderers(
        call: Call,
        pipRemoteCameraRenderer: RTCMTLVideoView,
        pipRemoteScreenRenderer: RTCMTLVideoView,
        pipVideoCallViewController: AVPictureInPictureVideoCallViewController
    ) {
        let camera = call.peerMediaSources.camera
        let screenVideo = call.peerMediaSources.screenVideo
        pipRemoteCameraRenderer.alpha = camera ? 1 : 0
        pipRemoteScreenRenderer.alpha = screenVideo ? 1 : 0

        if screenVideo {
            addSubviewAndResize(pipRemoteScreenRenderer, pipRemoteCameraRenderer, pip: true, into: pipVideoCallViewController.view)
        } else {
            addSubviewAndResize(pipRemoteCameraRenderer, pipRemoteScreenRenderer, pip: true, into: pipVideoCallViewController.view)
        }

        pxConfigurePipContentModes(pipVideoCallViewController: pipVideoCallViewController)
    }

    private func pxConfigurePipContentModes(pipVideoCallViewController: AVPictureInPictureVideoCallViewController) {
        guard pipVideoCallViewController.view.subviews.count >= 2,
              let v0 = pipVideoCallViewController.view.subviews[0] as? RTCMTLVideoView,
              let v1 = pipVideoCallViewController.view.subviews[1] as? RTCMTLVideoView else { return }
        v0.videoContentMode = contentMode
        v1.videoContentMode = .scaleAspectFill
    }

    private func pxSetupPipEnableHandler(pipController: AVPictureInPictureController, context: Context) {
        DispatchQueue.main.async {
            enablePip = { enable in
                pxTogglePipState(enable: enable, pipController: pipController)
            }
        }
    }

    private func pxTogglePipState(enable: Bool, pipController: AVPictureInPictureController) {
        if enable != pipShown {
            if enable {
                pipController.startPictureInPicture()
            } else {
                pipController.stopPictureInPicture()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(client)
    }

    // POPOPX: update remote video renderers when state changes
    func updateUIView(_ view: UIView, context: Context) {
        logger.debug("CallView.updateUIView remote")

        // POPOPX: safely find renderers by tag
        guard let camera = view.subviews.first(where: { $0.tag == 0 }),
              let screen = view.subviews.first(where: { $0.tag == 1 }) else { return }

        let screenVideo = call.peerMediaSources.screenVideo

        // POPOPX: swap layer order when screen share toggles
        if screenVideo && screen.alpha == 0 {
            screen.alpha = 1
            addSubviewAndResize(screen, camera, into: view)
        } else if !screenVideo && screen.alpha == 1 {
            screen.alpha = 0
            addSubviewAndResize(camera, screen, into: view)
        }

        // POPOPX: update content modes
        if view.subviews.count >= 2,
           let v0 = view.subviews[0] as? RTCMTLVideoView,
           let v1 = view.subviews[1] as? RTCMTLVideoView {
            v0.videoContentMode = contentMode
            v1.videoContentMode = .scaleAspectFill
        }

        // POPOPX: update visibility based on media source availability
        camera.alpha = call.peerMediaSources.camera ? 1 : 0
        screen.alpha = call.peerMediaSources.screenVideo ? 1 : 0

        DispatchQueue.main.async {
            if activeCallViewIsCollapsed != pipShown {
                enablePip(activeCallViewIsCollapsed)
            } else if pipShown {
                context.coordinator.relayout()
            }
        }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.cleanup()
    }
    
    // POPOPX: Coordinator handles PiP lifecycle events
    class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var cameraRenderer: RTCMTLVideoView?
        var screenRenderer: RTCMTLVideoView?
        weak var client: WebRTCClient?
        var pipController: AVPictureInPictureController? = nil
        var willShowHide: (Bool) -> Void = { _ in }
        var didShowHide: (Bool) -> Void = { _ in }
        var relayout: () -> Void = {}

        required init(_ client: WebRTCClient) {
            self.client = client
        }

        // MARK: - PiP Delegate Methods
        func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            willShowHide(true)
        }

        func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            didShowHide(true)
        }

        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
            logger.error("PiP failed to start: \(error.localizedDescription)")
        }

        func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            willShowHide(false)
        }

        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            didShowHide(false)
        }

        deinit {
            cleanup()
        }

        // POPOPX: clean up PiP controller and renderers
        func cleanup() {
            pipController?.stopPictureInPicture()
            pipController?.canStartPictureInPictureAutomaticallyFromInline = false
            pipController?.contentSource = nil
            pipController?.delegate = nil
            pipController = nil

            if let cameraRenderer {
                client?.removeRemoteCameraRenderer(cameraRenderer)
            }
            if let screenRenderer {
                client?.removeRemoteScreenRenderer(screenRenderer)
            }
        }
    }
    
    // POPOPX: SampleBufferVideoCallView for advanced video rendering
    class SampleBufferVideoCallView: UIView {
        override class var layerClass: AnyClass {
            get { return AVSampleBufferDisplayLayer.self }
        }

        var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer? {
            return layer as? AVSampleBufferDisplayLayer
        }
    }
}

// POPOPX: Local video renderer for user's own camera
struct CallViewLocal: UIViewRepresentable {
    var client: WebRTCClient
    var localRendererAspectRatio: Binding<CGFloat?>
    @State var pipStateChanged: (Bool) -> Void = {_ in }
    @Binding var pipShown: Bool

    init(client: WebRTCClient, localRendererAspectRatio: Binding<CGFloat?>, pipShown: Binding<Bool>) {
        self.client = client
        self.localRendererAspectRatio = localRendererAspectRatio
        self._pipShown = pipShown
    }

    // POPOPX: set up local camera renderer
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let localRenderer = RTCMTLVideoView(frame: .zero)
        context.coordinator.renderer = localRenderer
        client.addLocalRenderer(localRenderer)
        addSubviewAndResize(localRenderer, nil, into: view)

        DispatchQueue.main.async {
            pipStateChanged = { shown in
                localRenderer.isHidden = shown
            }
        }
        return view
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(client)
    }

    func updateUIView(_ view: UIView, context: Context) {
        logger.debug("CallView.updateUIView local")
        pipStateChanged(pipShown)
    }

    // POPOPX: Coordinator manages local renderer lifecycle
    class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var renderer: RTCMTLVideoView?
        weak var client: WebRTCClient?

        required init(_ client: WebRTCClient) {
            self.client = client
        }

        deinit {
            if let renderer {
                client?.removeLocalRenderer(renderer)
            }
        }
    }
}

private func addSubviewAndResize(_ pxFsView: UIView, _ pxEndView: UIView?, pip pxIsPip: Bool = false, into pxContainer: UIView) {
    if pxContainer.subviews.firstIndex(of: pxFsView) == 0 && ((pxEndView == nil && pxContainer.subviews.count == 1) || (pxEndView != nil && pxContainer.subviews.firstIndex(of: pxEndView!) == 1)) {
        // Nothing to do, elements on their places
        return
    }
    pxContainer.removeConstraints(pxContainer.constraints)
    pxContainer.subviews.forEach { pxSub in pxSub.removeFromSuperview()}

    pxContainer.addSubview(pxFsView)
    pxFsView.translatesAutoresizingMaskIntoConstraints = false
    pxFsView.layer.cornerRadius = 0
    pxFsView.layer.masksToBounds = false

    if let pxEndView {
        pxContainer.addSubview(pxEndView)
        pxEndView.translatesAutoresizingMaskIntoConstraints = false
        pxEndView.layer.cornerRadius = pxIsPip ? PXCallRendererConfig.pxPipCorner : PXCallRendererConfig.pxFullCorner
        pxEndView.layer.masksToBounds = true
    }

    let pxFsVertConstraint = NSLayoutConstraint.constraints(
        withVisualFormat: "V:|[pxFsView]|",
        options: [],
        metrics: nil,
        views: ["pxFsView": pxFsView]
    )
    let pxFsHorizConstraint = NSLayoutConstraint.constraints(
        withVisualFormat: "H:|[pxFsView]|",
        options: [],
        metrics: nil,
        views: ["pxFsView": pxFsView]
    )

    pxContainer.addConstraints(pxFsVertConstraint)
    pxContainer.addConstraints(pxFsHorizConstraint)

    if let pxEndView {
        let pxScale = pxIsPip ? PXCallRendererConfig.pxPipScale : PXCallRendererConfig.pxNormalScale
        let pxEndWidthConstraint = NSLayoutConstraint(
            item: pxEndView, attribute: .width, relatedBy: .equal, toItem: pxContainer, attribute: .width, multiplier: pxScale, constant: 0
        )
        let pxEndHeightConstraint = NSLayoutConstraint(
            item: pxEndView, attribute: .height, relatedBy: .equal, toItem: pxContainer, attribute: .width, multiplier: pxScale * PXCallRendererConfig.pxOverlayAspect, constant: 0
        )
        let pxXPos = pxIsPip ? PXCallRendererConfig.pxPipXPos : PXCallRendererConfig.pxNormalXPos
        let pxXOff = pxIsPip ? PXCallRendererConfig.pxPipXOffset : PXCallRendererConfig.pxNormalXOffset
        let pxEndXConstraint = NSLayoutConstraint(
            item: pxEndView, attribute: .leading, relatedBy: .equal, toItem: pxContainer, attribute: .trailing, multiplier: pxXPos, constant: pxXOff
        )
        let pxYOff = pxIsPip ? PXCallRendererConfig.pxPipYOffset : PXCallRendererConfig.pxNormalYOffset
        let pxEndYConstraint = NSLayoutConstraint(
            item: pxEndView, attribute: .bottom, relatedBy: .equal, toItem: pxContainer, attribute: .bottom, multiplier: 1, constant: pxYOff
        )
        pxContainer.addConstraint(pxEndWidthConstraint)
        pxContainer.addConstraint(pxEndHeightConstraint)
        pxContainer.addConstraint(pxEndXConstraint)
        pxContainer.addConstraint(pxEndYConstraint)
    }
    pxContainer.layoutIfNeeded()
}

// MARK: - POPOPX
extension CallViewRemote {
    static let pxComponentTag: String = "PX_CALL_VIEW_RENDERERS"
    static let pxPreferredPipSize = CGSize(width: 1080, height: 1920)
}
