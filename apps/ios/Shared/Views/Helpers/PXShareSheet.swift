//
//  ShareSheet.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 30/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxShareFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")

/// POPOPX: Alert and sheet appearance configuration
private enum PXAlertConfig {
    static let pxOverlayAlpha: CGFloat = 0.32
    static let pxContainerCornerRadius: CGFloat = 14
    static let pxProfileStackSpacing: CGFloat = 14
    static let pxMainStackSpacing: CGFloat = 18
    static let pxContainerWidth: CGFloat = 270
    static let pxButtonMinHeight: CGFloat = 44
    static let pxProfileImageDimension: CGFloat = 103
    static let pxDisplayScaleFallback: CGFloat = UIScreen.main.scale
    static let pxContentInset: CGFloat = 20
}

/// POPOPX: Domain-specific URL configuration
private enum PXDomainConfig {
    static let pxContactURLPrefix = "https://popopxchat.com/contact#"
    static let pxSMPPrefix = "https://smp"
    static let pxSMPDomainPattern = ".popopxchat.com/a#"
}

// MARK: - POPOPX View Controller Resolution

func getTopViewController() -> UIViewController? {
    // First try to find a foregroundActive scene
    var keyWindowScene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
    // Fall back to foregroundInactive if no active scene (happens during UI transitions)
    if keyWindowScene == nil {
        keyWindowScene = pxResolveFallbackScene()
    }
    logger.debug("getTopViewController: keyWindowScene=\(keyWindowScene != nil)")
    guard let pxScene = keyWindowScene else {
        logger.debug("getTopViewController: returning nil")
        return nil
    }
    return pxResolveTopController(from: pxScene)
}

private func pxResolveFallbackScene() -> UIWindowScene? {
    UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundInactive } as? UIWindowScene
}

private func pxResolveTopController(from scene: UIWindowScene) -> UIViewController? {
    guard let keyWindow = scene.windows.filter(\.isKeyWindow).first,
          let rootViewController = keyWindow.rootViewController else {
        logger.debug("getTopViewController: no key window or root VC")
        return nil
    }
    var topController = rootViewController
    while let presentedViewController = topController.presentedViewController {
        topController = presentedViewController
    }
    logger.debug("getTopViewController: found topController=\(type(of: topController))")
    return topController
}

func showShareSheet(items: [Any], completed: (() -> Void)? = nil) {
    logger.debug("PX: [showShareSheet] called with \(items.count) items")
    guard let pxTopController = getTopViewController() else {
        logger.debug("PX: [showShareSheet] no top controller")
        return
    }
    let pxActivityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
    if let completed = completed {
        pxActivityVC.completionWithItemsHandler = { _, _, _, _ in
            completed()
        }
    }
    pxTopController.present(pxActivityVC, animated: true)
}

func showAlert(
    title: String,
    message: String? = nil,
    buttonTitle: String,
    buttonAction: @escaping () -> Void,
    cancelButton: Bool
) -> Void {
    guard let pxTopController = getTopViewController() else { return }
    logger.debug("PX: [showAlert] title=\(title)")
    let pxAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    pxAlert.addAction(UIAlertAction(title: buttonTitle, style: .default) { _ in
        buttonAction()
    })
    if cancelButton {
        pxAlert.addAction(cancelAlertAction)
    }
    pxTopController.present(pxAlert, animated: true)
}

func showAlert(_ a: (title: String, message: String?)) {
    showAlert(a.title, message: a.message)
}

func showErrorAlert(_ error: Error, _ title: String) {
    let err = { String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: ""), responseError(error)) }
    if let r = error as? ChatError,
       let alert = getNetworkErrorAlert(r) {
        showAlert(alert.title, message: alert.message ?? err())
    } else {
        showAlert(title, message: err())
    }
}

func showAlert(
    _ title: String,
    message: String? = nil,
    actions: () -> [UIAlertAction] = { [okAlertAction] }
) {
    guard let pxTopController = getTopViewController() else { return }
    logger.debug("PX: [showAlert:actions] title=\(title)")
    let pxAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    for action in actions() { pxAlert.addAction(action) }
    pxTopController.present(pxAlert, animated: true)
}

func showSheet(
    _ title: String?,
    message: String? = nil,
    actions: () -> [UIAlertAction] = { [okAlertAction] },
    sourceView: UIView? = nil  // For iPad support
) {
    logger.debug("showSheet: called with title=\(title ?? "nil")")
    if let topController = getTopViewController() {
        let sheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        for action in actions() { sheet.addAction(action) }

        // Required for iPad: Configure popover presentation
        pxConfigurePopover(for: sheet, on: topController, sourceView: sourceView)
        topController.present(sheet, animated: true)
    } else {
        logger.debug("showSheet: no top controller available, sheet NOT presented")
    }
}

private func pxConfigurePopover(
    for sheet: UIAlertController,
    on controller: UIViewController,
    sourceView: UIView?
) {
    if let popover = sheet.popoverPresentationController {
        popover.sourceView = sourceView ?? controller.view
        popover.sourceRect = sourceView?.bounds ?? CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
    }
}

@MainActor
func openExternalLink(_ url: URL) {
    let s = url.absoluteString
    if pxIsInternalDomainURL(s) {
        ChatModel.shared.appOpenUrl = url
    } else {
        showAlert(
            title: NSLocalizedString("Open external link?", comment: "alert title"),
            message: s,
            buttonTitle: NSLocalizedString("Open", comment: "alert button"),
            buttonAction: { UIApplication.shared.open(url) },
            cancelButton: true
        )
    }
}

private func pxIsInternalDomainURL(_ urlString: String) -> Bool {
    urlString.starts(with: PXDomainConfig.pxContactURLPrefix)
        || (urlString.starts(with: PXDomainConfig.pxSMPPrefix)
            && urlString.contains(PXDomainConfig.pxSMPDomainPattern))
}

struct ExternalLink<Label: View>: View {
    let destination: URL
    let label: Label

    init(destination: URL, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }

    init(_ titleKey: LocalizedStringKey, destination: URL) where Label == Text {
        self.destination = destination
        self.label = Text(titleKey)
    }

    var body: some View {
        Button { openExternalLink(destination) } label: { label }
        .popopxBranded()
    }
}

let okAlertAction = UIAlertAction(title: NSLocalizedString("Ok", comment: "alert button"), style: .default)

let cancelAlertAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "alert button"), style: .cancel)

let alertProfileImageSize: CGFloat = PXAlertConfig.pxProfileImageDimension

let alertWidth: CGFloat = PXAlertConfig.pxContainerWidth

let alertButtonHeight: CGFloat = PXAlertConfig.pxButtonMinHeight

class OpenChatAlertViewController: UIViewController {
    private let profileName: String
    private let profileFullName: String
    private let profileImage: UIView
    private let profileBadge: LocalBadge?
    private let subtitle: String?
    private let information: String?
    private let secondaryInformation: Bool
    private let cancelTitle: String
    private let confirmTitle: String?
    private let secondTitle: String?
    private let onCancel: () -> Void
    private let onConfirm: (() -> Void)?
    private let onSecond: (() -> Void)?

    init(
        profileName: String,
        profileFullName: String,
        profileImage: UIView,
        profileBadge: LocalBadge? = nil,
        subtitle: String? = nil,
        information: String? = nil,
        secondaryInformation: Bool = false,
        cancelTitle: String = NSLocalizedString("Cancel", comment: "alert button"),
        confirmTitle: String? = NSLocalizedString("Open", comment: "alert button"),
        secondTitle: String? = nil,
        onCancel: @escaping () -> Void = {},
        onConfirm: (() -> Void)? = nil,
        onSecond: (() -> Void)? = nil
    ) {
        self.profileName = profileName
        self.profileFullName = profileFullName
        self.profileImage = profileImage
        self.profileBadge = profileBadge
        self.subtitle = subtitle
        self.information = information
        self.secondaryInformation = secondaryInformation
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.secondTitle = secondTitle
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.onSecond = onSecond
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        pxSetupOverlayBackground()
        let containerView = pxCreateContainerView()
        view.addSubview(containerView)
        pxConfigureProfileImageSizing()

        let profileViews = pxBuildProfileViewList()
        let stack = pxCreateProfileStack(views: profileViews)
        let topRowContainer = pxCreateTopRowContainer(stack: stack)

        let (buttonStack, buttonDividerConstraints) = pxBuildButtonStack(in: containerView)
        let vStack = pxCreateVerticalStack(top: topRowContainer, buttons: buttonStack)
        containerView.addSubview(vStack)

        let horizontalDivider = pxCreateHorizontalDivider()
        containerView.addSubview(horizontalDivider)

        pxActivateConstraints(
            containerView: containerView,
            vStack: vStack,
            stack: stack,
            buttonStack: buttonStack,
            horizontalDivider: horizontalDivider,
            buttonDividerConstraints: buttonDividerConstraints
        )
    }

    // MARK: - POPOPX View Construction Helpers

    private func pxSetupOverlayBackground() {
        view.backgroundColor = UIColor.black.withAlphaComponent(PXAlertConfig.pxOverlayAlpha)
    }

    private func pxCreateContainerView() -> UIView {
        let cv = UIView()
        cv.backgroundColor = .systemBackground
        cv.layer.cornerRadius = PXAlertConfig.pxContainerCornerRadius
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }

    private func pxConfigureProfileImageSizing() {
        profileImage.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            profileImage.widthAnchor.constraint(equalToConstant: PXAlertConfig.pxProfileImageDimension),
            profileImage.heightAnchor.constraint(equalToConstant: PXAlertConfig.pxProfileImageDimension)
        ])
    }

    private func pxBuildProfileViewList() -> [UIView] {
        var views = pxBuildCoreProfileViews()
        if let subtitle { views.append(pxCreateSubtitleLabel(text: subtitle)) }
        if let information { views.append(pxCreateInformationLabel(text: information, secondary: secondaryInformation)) }
        return views
    }

    private func pxBuildCoreProfileViews() -> [UIView] {
        let nameLabel = pxCreateNameLabel()
        var coreViews = [profileImage, nameLabel]
        if !profileFullName.isEmpty && profileFullName != profileName {
            coreViews.append(pxCreateFullNameLabel())
        }
        return coreViews
    }

    private func pxCreateNameLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.numberOfLines = 2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        if let badge = nameBadgeAttachment(profileBadge, font: label.font) {
            let s = NSMutableAttributedString(string: profileName)
            s.append(badge)
            label.attributedText = s
        } else {
            label.text = profileName
        }
        return label
    }

    private func pxCreateFullNameLabel() -> UILabel {
        let label = UILabel()
        label.text = profileFullName
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .label
        label.numberOfLines = 2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func pxCreateSubtitleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 3
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func pxCreateInformationLabel(text: String, secondary: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = secondary ? .secondaryLabel : .label
        label.numberOfLines = 3
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func pxCreateProfileStack(views: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = PXAlertConfig.pxProfileStackSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func pxCreateTopRowContainer(stack: UIStackView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        let inset = PXAlertConfig.pxContentInset
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset)
        ])
        return container
    }

    private func pxBuildButtonStack(in containerView: UIView) -> (UIStackView, [NSLayoutConstraint]) {
        let cancelButton = pxCreateCancelButton()
        var buttonDividerConstraints: [NSLayoutConstraint] = []

        let buttonStack: UIStackView
        if let confirmTitle, let secondTitle {
            let (stack, constraints) = pxCreateThreeButtonStack(
                confirmTitle: confirmTitle,
                secondTitle: secondTitle,
                cancel: cancelButton,
                container: containerView
            )
            buttonStack = stack
            buttonDividerConstraints = constraints
        } else if let confirmTitle {
            let (stack, constraints) = pxCreateConditionalButtonStack(
                confirmTitle: confirmTitle,
                cancel: cancelButton,
                container: containerView
            )
            buttonStack = stack
            buttonDividerConstraints = constraints
        } else {
            buttonStack = pxCreateSingleButtonStack(cancel: cancelButton)
        }
        return (buttonStack, buttonDividerConstraints)
    }

    private func pxCreateCancelButton() -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(cancelTitle, for: .normal)
        let bodyDescr = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        btn.titleLabel?.font = UIFont(descriptor: bodyDescr.withSymbolicTraits(.traitBold) ?? bodyDescr, size: 0)
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return btn
    }

    private func pxCreateThreeButtonStack(
        confirmTitle: String, secondTitle: String,
        cancel: UIButton, container: UIView
    ) -> (UIStackView, [NSLayoutConstraint]) {
        let confirmBtn = pxCreateActionButton(title: confirmTitle, action: #selector(confirmTapped))
        let secondBtn = pxCreateActionButton(title: secondTitle, action: #selector(secondTapped))
        let stack = UIStackView(arrangedSubviews: [confirmBtn, secondBtn, cancel])
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.heightAnchor.constraint(greaterThanOrEqualToConstant: alertButtonHeight * 3).isActive = true
        var constraints: [NSLayoutConstraint] = []
        for button in [secondBtn, cancel] {
            constraints += pxCreateVerticalDivider(for: button, in: container)
        }
        return (stack, constraints)
    }

    private func pxCreateActionButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func pxCreateConditionalButtonStack(
        confirmTitle: String, cancel: UIButton, container: UIView
    ) -> (UIStackView, [NSLayoutConstraint]) {
        let confirmBtn = pxCreateActionButton(title: confirmTitle, action: #selector(confirmTapped))
        let verticalButtons = cancel.intrinsicContentSize.width + 20 >= alertWidth / 2
            || confirmBtn.intrinsicContentSize.width + 20 >= alertWidth / 2
        let stack = UIStackView(arrangedSubviews: verticalButtons ? [confirmBtn, cancel] : [cancel, confirmBtn])
        stack.axis = verticalButtons ? .vertical : .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.heightAnchor.constraint(greaterThanOrEqualToConstant: alertButtonHeight * (verticalButtons ? 2 : 1)).isActive = true
        let divider = UIView()
        divider.backgroundColor = UIColor.separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        stack.addSubview(divider)
        let constraints = pxCreateButtonDivider(
            divider: divider, vertical: verticalButtons, in: container, buttonStack: stack
        )
        return (stack, constraints)
    }

    private func pxCreateSingleButtonStack(cancel: UIButton) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [cancel])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.heightAnchor.constraint(greaterThanOrEqualToConstant: alertButtonHeight).isActive = true
        return stack
    }

    private func pxCreateVerticalDivider(for button: UIButton, in container: UIView) -> [NSLayoutConstraint] {
        let divider = UIView()
        divider.backgroundColor = UIColor.separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(divider)
        let pixelHeight = 1 / self.traitCollection.displayScale
        return [
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: button.topAnchor),
            divider.heightAnchor.constraint(equalToConstant: pixelHeight)
        ]
    }

    private func pxCreateButtonDivider(
        divider: UIView, vertical: Bool,
        in container: UIView, buttonStack: UIStackView
    ) -> [NSLayoutConstraint] {
        let pixelSize = 1 / self.traitCollection.displayScale
        if vertical {
            return [
                divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                divider.centerYAnchor.constraint(equalTo: buttonStack.centerYAnchor),
                divider.heightAnchor.constraint(equalToConstant: pixelSize)
            ]
        } else {
            return [
                divider.topAnchor.constraint(equalTo: buttonStack.topAnchor),
                divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                divider.centerXAnchor.constraint(equalTo: buttonStack.centerXAnchor),
                divider.widthAnchor.constraint(equalToConstant: pixelSize)
            ]
        }
    }

    private func pxCreateVerticalStack(top: UIView, buttons: UIStackView) -> UIStackView {
        let vs = UIStackView(arrangedSubviews: [top, buttons])
        vs.axis = .vertical
        vs.spacing = PXAlertConfig.pxMainStackSpacing
        vs.alignment = .fill
        vs.translatesAutoresizingMaskIntoConstraints = false
        return vs
    }

    private func pxCreateHorizontalDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = UIColor.separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        return divider
    }

    private func pxActivateConstraints(
        containerView: UIView, vStack: UIStackView, stack: UIStackView,
        buttonStack: UIStackView, horizontalDivider: UIView,
        buttonDividerConstraints: [NSLayoutConstraint]
    ) {
        let pixelHeight = 1 / self.traitCollection.displayScale
        NSLayoutConstraint.activate([
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.widthAnchor.constraint(equalToConstant: PXAlertConfig.pxContainerWidth),
            vStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: PXAlertConfig.pxContentInset),
            vStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 0),
            vStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 0),
            vStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0),
            stack.centerXAnchor.constraint(equalTo: vStack.centerXAnchor),
            horizontalDivider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            horizontalDivider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            horizontalDivider.bottomAnchor.constraint(equalTo: buttonStack.topAnchor),
            horizontalDivider.heightAnchor.constraint(equalToConstant: pixelHeight)
        ] + buttonDividerConstraints)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) {
            self.onCancel()
        }
    }

    @objc private func confirmTapped() {
        dismiss(animated: true) {
            self.onConfirm?()
        }
    }

    @objc private func secondTapped() {
        dismiss(animated: true) {
            self.onSecond?()
        }
    }
}


func showOpenChatAlert<Content: View>(
    profileName: String,
    profileFullName: String,
    profileImage: Content,
    profileBadge: LocalBadge? = nil,
    theme: AppTheme,
    subtitle: String? = nil,
    information: String? = nil,
    secondaryInformation: Bool = false,
    cancelTitle: String = NSLocalizedString("Cancel", comment: "alert button"),
    confirmTitle: String? = NSLocalizedString("Open", comment: "alert button"),
    secondTitle: String? = nil,
    onCancel: @escaping () -> Void = {},
    onConfirm: (() -> Void)? = nil,
    onSecond: (() -> Void)? = nil
) {
    let themedView = profileImage.environmentObject(theme)
    let hostingController = UIHostingController(rootView: themedView)
    guard let hostedView = hostingController.view else { return }
    hostedView.backgroundColor = .clear

    if let topVC = getTopViewController() {
        let alertVC = OpenChatAlertViewController(
            profileName: profileName,
            profileFullName: profileFullName,
            profileImage: hostedView,
            profileBadge: profileBadge,
            subtitle: subtitle,
            information: information,
            secondaryInformation: secondaryInformation,
            cancelTitle: cancelTitle,
            confirmTitle: confirmTitle,
            secondTitle: secondTitle,
            onCancel: onCancel,
            onConfirm: onConfirm,
            onSecond: onSecond
        )
        topVC.present(alertVC, animated: true)
    }
}

// MARK: - POPOPX Component Tag

private let pxComponentTag = "PXShareSheet"
private let pxAlertOverlayAlpha: CGFloat = PXAlertConfig.pxOverlayAlpha
private let pxAlertContainerCornerRadius: CGFloat = PXAlertConfig.pxContainerCornerRadius
private let pxAlertProfileStackSpacing: CGFloat = PXAlertConfig.pxProfileStackSpacing
private let pxAlertMainStackSpacing: CGFloat = PXAlertConfig.pxMainStackSpacing
