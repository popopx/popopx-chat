//
//  SwiftUISheet.swift
//  POPOPX (iOS)
//
//  Created by user on 23/09/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

// POPOPX: sheet animation and layout constants
private enum PXSheetMetrics {
    static let pxAnimDuration: Double = 0.30
    static let pxCornerRadius: CGFloat = 16
    static let pxOverlayAlphaLight: CGFloat = 0.14
    static let pxOverlayAlphaDark: CGFloat = 0.27
    static let pxPanVelocityFactor: CGFloat = 110
    static let pxSnapThreshold: CGFloat = 0.45
    static let pxMinDurationFactor: CGFloat = 0.5
    static let pxMaxDurationFactor: CGFloat = 1.0
}

// POPOPX: custom easing – Reference: https://easings.net/
private let pxEaseOutCubicParams = UICubicTimingParameters(
    controlPoint1: CGPoint(x: 0.22, y: 0.62),
    controlPoint2: CGPoint(x: 0.36, y: 1)
)

private let pxEaseInDismissParams = UICubicTimingParameters(animationCurve: .easeIn)

struct Sheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        ZStack {
            content
            SheetRepresentable(isPresented: $isPresented, content: sheetContent())
                .allowsHitTesting(isPresented)
                .ignoresSafeArea()
        }
    }
}

struct SheetRepresentable<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content:  Content

    func makeUIViewController(context: Context) -> Controller<Content> {
        Controller(content: content, representer: self)
    }

    func updateUIViewController(_ sheetController: Controller<Content>, context: Context) {
        sheetController.animate(isPresented: isPresented)
    }

    class Controller<C: View>: UIViewController {
        let hostingController: UIHostingController<C>
        private let pxAnimator = UIViewPropertyAnimator(
            duration: PXSheetMetrics.pxAnimDuration,
            timingParameters: pxEaseOutCubicParams
        )
        private let representer: SheetRepresentable<C>
        private var pxRetainedFraction: CGFloat = 0
        private var pxSheetHeight: Double { hostingController.view.frame.height }
        private var pxVisibilityTask: Task<Void, Never>?

        init(content: C, representer: SheetRepresentable<C>) {
            self.representer = representer
            self.hostingController = UIHostingController(rootView: content)
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) missing") }

        deinit {
            pxAnimator.stopAnimation(true)
            pxAnimator.finishAnimation(at: .current)
        }

        // POPOPX: drive the present/dismiss animation with custom easing
        func animate(isPresented: Bool) {
            let pxAlreadyRunning = pxAnimator.isRunning && isPresented != pxAnimator.isReversed
            let pxFullyDismissed = pxAnimator.fractionComplete == (pxAnimator.isReversed ? 1 : 0)
            let pxFullyShown = pxAnimator.fractionComplete == (pxAnimator.isReversed ? 0 : 1)

            if pxShouldSkipAnimation(
                isPresented: isPresented,
                fullyDismissed: pxFullyDismissed,
                fullyShown: pxFullyShown,
                alreadyRunning: pxAlreadyRunning
            ) {
                return
            }

            pxAnimator.pauseAnimation()
            pxAnimator.isReversed = !isPresented
            pxAnimator.continueAnimation(
                withTimingParameters: isPresented ? pxEaseOutCubicParams : pxEaseInDismissParams,
                durationFactor: 1 - pxAnimator.fractionComplete
            )
            pxHandleVisibilityAfterAnimation()
        }

        // MARK: - POPOPX extracted helpers

        private func pxShouldSkipAnimation(isPresented: Bool, fullyDismissed: Bool, fullyShown: Bool, alreadyRunning: Bool) -> Bool {
            (!isPresented && fullyDismissed) || (isPresented && fullyShown) || alreadyRunning
        }

        func pxHandleVisibilityAfterAnimation() {
            pxUpdateVisibility()
        }

        func handleVisibility() {
            pxUpdateVisibility()
        }

        private func pxUpdateVisibility() {
            if pxAnimator.isReversed {
                pxScheduleHide()
            } else {
                pxCancelScheduledHideAndShow()
            }
        }

        private func pxScheduleHide() {
            pxVisibilityTask = Task {
                do {
                    let pxSleepNs = UInt64(PXSheetMetrics.pxAnimDuration * Double(NSEC_PER_SEC))
                    try await Task.sleep(nanoseconds: pxSleepNs)
                    view.isHidden = true
                } catch {
                    logger.error("SheetRepresentable: Task.sleep failed: \(error.localizedDescription)")
                }
            }
        }

        private func pxCancelScheduledHideAndShow() {
            pxVisibilityTask?.cancel()
            pxVisibilityTask = nil
            view.isHidden = false
        }

        override func viewDidLoad() {
            view.isHidden = true
            view.backgroundColor = .clear
            view.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(tap(gesture:)))
            )
            addChild(hostingController)
            hostingController.didMove(toParent: self)
            pxConfigureSheetView()
        }

        // MARK: - POPOPX sheet view configuration
        private func pxConfigureSheetView() {
            guard let pxSheetView = hostingController.view else { return }
            pxSheetView.isHidden = true
            pxSheetView.clipsToBounds = true
            pxSheetView.layer.cornerRadius = PXSheetMetrics.pxCornerRadius
            pxSheetView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
            pxSheetView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(gesture:))))
            pxSheetView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(pxSheetView)
            pxActivateLayoutConstraints(for: pxSheetView)
        }

        private func pxActivateLayoutConstraints(for sheetView: UIView) {
            NSLayoutConstraint.activate([
                sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        override func viewDidAppear(_ animated: Bool) {
            // POPOPX: ensures animations are only setup once
            // on some iOS version `viewDidAppear` can get called on each state change.
            guard hostingController.view.isHidden else { return }
            pxPerformInitialAnimation()
        }

        // MARK: - POPOPX initial presentation animation
        private func pxPerformInitialAnimation() {
            hostingController.view.transform = CGAffineTransform(translationX: 0, y: self.pxSheetHeight)
            hostingController.view.isHidden = false
            pxAnimator.pausesOnCompletion = true
            pxAnimator.addAnimations {
                self.hostingController.view.transform = .identity
                self.view.backgroundColor = self.pxOverlayColor()
            }
            pxAnimator.startAnimation()
            pxAnimator.pauseAnimation()
        }

        private func pxOverlayColor() -> UIColor {
            UIColor { traitCollection in
                let alpha = traitCollection.userInterfaceStyle == .dark
                    ? PXSheetMetrics.pxOverlayAlphaDark
                    : PXSheetMetrics.pxOverlayAlphaLight
                return .black.withAlphaComponent(alpha)
            }
        }

        @objc
        func pan(gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                pxAnimator.isReversed = false
                pxAnimator.pauseAnimation()
                pxRetainedFraction = pxAnimator.fractionComplete
            case .changed:
                pxAnimator.fractionComplete = pxRetainedFraction - gesture.translation(in: view).y / pxSheetHeight
            case .ended, .cancelled:
                pxHandlePanEnded(gesture: gesture)
            default: break
            }
        }

        // MARK: - POPOPX pan gesture completion
        private func pxHandlePanEnded(gesture: UIPanGestureRecognizer) {
            let pxVelocity = gesture.velocity(in: view).y
            // POPOPX: snap decision based on velocity and current fraction
            pxAnimator.isReversed = (pxVelocity - (pxAnimator.fractionComplete - PXSheetMetrics.pxSnapThreshold) * PXSheetMetrics.pxPanVelocityFactor).sign == .plus
            let pxDefaultSpeed = pxSheetHeight / PXSheetMetrics.pxAnimDuration
            let pxFractionLeft = 1 - pxAnimator.fractionComplete
            let pxDurationFactor = min(
                max(pxFractionLeft / (abs(pxVelocity) / pxDefaultSpeed), PXSheetMetrics.pxMinDurationFactor),
                PXSheetMetrics.pxMaxDurationFactor
            )
            pxAnimator.continueAnimation(withTimingParameters: nil, durationFactor: pxDurationFactor * pxFractionLeft)
            handleVisibility()
            DispatchQueue.main.asyncAfter(deadline: .now() + PXSheetMetrics.pxAnimDuration) { [weak self] in
                guard let self else { return }
                self.representer.isPresented = !self.pxAnimator.isReversed
            }
        }

        @objc
        func tap(gesture: UITapGestureRecognizer) {
            switch gesture.state {
            case .ended:
                let pxTapBelowSheet = gesture.location(in: view).y >= view.frame.height - pxSheetHeight
                if !pxTapBelowSheet {
                    representer.isPresented = false
                }
            default: break
            }
        }
    }
}

// MARK: - POPOPX Component Identity

extension SheetRepresentable {
    var pxComponentIdentifier: String { "PXSheetRepresentable" }
}

extension Sheet {
    var pxComponentIdentifier: String { "PXSheetModifier" }
}
