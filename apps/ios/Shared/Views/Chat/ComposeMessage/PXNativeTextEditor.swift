//
//  NativeTextEditor.swift
//  POPOPX (iOS)
//
//  Created by Avently on 15.12.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import SwiftyGif
import POPOPXSwitch
import PhotosUI

// MARK: - POPOPX Layout Configuration
private enum PXNativeTextEditorConfig {
    // Background colors
    static let lightBgWhite: CGFloat = 0.95
    static let darkBgClear: Bool = true
    // Cursor tint (RGB)
    static let cursorTintRed: CGFloat = 0
    static let cursorTintGreen: CGFloat = 255.0 / 255.0
    static let cursorTintBlue: CGFloat = 210.0 / 255.0
    // Text container insets
    static let insetTop: CGFloat = 9
    static let insetLeft: CGFloat = 5
    static let insetBottom: CGFloat = 7
    static let insetRight: CGFloat = 4
    // Placeholder
    static let placeholderColorWhite: CGFloat = 147.0 / 255.0
    static let placeholderAlpha: CGFloat = 0.6
    static let placeholderFontSize: CGFloat = 14
    static let placeholderMonoWeight: UIFont.Weight = .regular
    static let placeholderLeadingInset: CGFloat = 7
    static let placeholderTrailingInset: CGFloat = -7
    static let placeholderTopInset: CGFloat = 8
    // Sizing
    static let minHeight: CGFloat = 39
    static let maxHeightLines: Int = 12
    static let maxAbsoluteHeight: CGFloat = 360
    // Paste sync queue
    static let pxSyncQueueLabel: String = "app.popopx.paste-sync"
    // Component tag
    static let componentTag: String = "PX_NATIVE_TEXT_EDITOR"
}

// MARK: - POPOPX View Model
private struct PXNativeTextEditorViewModel {
    let colorScheme: ColorScheme?

    var pxBackgroundColor: UIColor {
        if colorScheme == .light {
            return UIColor(white: PXNativeTextEditorConfig.lightBgWhite, alpha: 1.0)
        }
        return .clear
    }

    var pxCursorColor: UIColor {
        UIColor(
            red: PXNativeTextEditorConfig.cursorTintRed,
            green: PXNativeTextEditorConfig.cursorTintGreen,
            blue: PXNativeTextEditorConfig.cursorTintBlue,
            alpha: 1
        )
    }

    var pxTextContainerInsets: UIEdgeInsets {
        UIEdgeInsets(
            top: PXNativeTextEditorConfig.insetTop,
            left: PXNativeTextEditorConfig.insetLeft,
            bottom: PXNativeTextEditorConfig.insetBottom,
            right: PXNativeTextEditorConfig.insetRight
        )
    }

    var pxIsLightMode: Bool { colorScheme == .light }
}

struct NativeTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var disableEditing: Bool
    @Binding var height: CGFloat
    @Binding var focused: Bool
    @Binding var lastUnfocusedDate: Date
    @Binding var placeholder: String?
    @Binding var selectedRange: NSRange
    let onImagesAdded: ([UploadContent]) -> Void
    var colorScheme: ColorScheme?

    static let minHeight: CGFloat = PXNativeTextEditorConfig.minHeight

    func makeUIView(context: Context) -> CustomUITextField {
        let vm = PXNativeTextEditorViewModel(colorScheme: colorScheme)
        let field = CustomUITextField(parent: self, height: _height)
        field.backgroundColor = vm.pxBackgroundColor
        field.tintColor = vm.pxCursorColor
        field.text = text
        field.textAlignment = pxAlignment(text)
        field.autocapitalizationType = .sentences
        field.setOnTextChangedListener { newText, images in
            pxHandleTextChanged(field: field, newText: newText, images: images)
        }
        field.setOnFocusChangedListener {
            focused = $0
            if !focused {
                lastUnfocusedDate = .now
            }
        }
        field.delegate = field
        field.textContainerInset = vm.pxTextContainerInsets
        field.setPlaceholderView()
        field.updateFont()
        field.updateHeight(updateBindingNow: false)
        return field
    }

    func updateUIView(_ field: CustomUITextField, context: Context) {
        let vm = PXNativeTextEditorViewModel(colorScheme: colorScheme)
        field.backgroundColor = vm.pxBackgroundColor

        if field.markedTextRange == nil && field.text != text {
            field.text = text
            field.textAlignment = pxAlignment(text)
            field.updateFont()
            field.updateHeight(updateBindingNow: false)
            field.placeholder = text.isEmpty ? placeholder : ""
        }
        if field.placeholder != placeholder {
            field.placeholder = text.isEmpty ? placeholder : ""
        }
        if field.selectedRange != selectedRange {
            field.selectedRange = selectedRange
        }
// This block causes delays in closing keyboard when navigating from chat view to chat list.
// It is also a candidate for iOS 26.1 freeze.
// This was added in commit below to open keyboard programmatically via a passed binding but this approach is not reliable.
// https://github.com/simplex-chat/simplex-chat/pull/6003/commits/cb666de51375623451a5e80dcf59449adc7d2a5f
//        if focused && !field.isFocused {
//            DispatchQueue.main.async {
//                if !field.isFocused {
//                    field.becomeFirstResponder()
//                }
//            }
//        }
    }

    // MARK: - POPOPX Helpers

    private func pxHandleTextChanged(field: CustomUITextField, newText: String, images: [UploadContent]) {
        if !disableEditing {
            text = newText
            field.textAlignment = pxAlignment(text)
            field.updateFont()
            field.updateHeight()
        } else {
            field.text = text
        }
        if !images.isEmpty {
            onImagesAdded(images)
        }
    }
}

private func pxAlignment(_ text: String) -> NSTextAlignment {
    isRightToLeft(text) ? .right : .left
}

class CustomUITextField: UITextView, UITextViewDelegate {
    var parent: NativeTextEditor?
    var height: Binding<CGFloat>
    var newHeight: CGFloat = 0
    var onTextChanged: (String, [UploadContent]) -> Void = { newText, image in }
    var onFocusChanged: (Bool) -> Void = { focused in }

    private let placeholderLabel: UILabel = UILabel()

    init(parent: NativeTextEditor?, height: Binding<CGFloat>) {
        self.parent = parent
        self.height = height
        super.init(frame: .zero, textContainer: nil)
        self.delegate = self
    }

    var placeholder: String? {
        get { placeholderLabel.text }
        set { placeholderLabel.text = newValue }
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    // This func here needed because using frame.size.height in intrinsicContentSize while loading a screen with text (for example. when you have a draft),
    // produces incorrect height because at that point intrinsicContentSize has old value of frame.size.height even if it was set to new value right before the call
    // (who knows why...)
    func invalidateIntrinsicContentHeight(_ newHeight: CGFloat) {
        self.newHeight = newHeight
        invalidateIntrinsicContentSize()
    }

    func updateHeight(updateBindingNow: Bool = true) {
        let maxLineHeight = CGFloat(PXNativeTextEditorConfig.maxHeightLines)
        let maxHeight = min(
            PXNativeTextEditorConfig.maxAbsoluteHeight,
            (font ?? UIFont.preferredFont(forTextStyle: .body)).lineHeight * maxLineHeight
        )
        let computed = sizeThatFits(CGSizeMake(frame.size.width, CGFloat.greatestFiniteMagnitude)).height
        let clamped = min(max(computed, PXNativeTextEditorConfig.minHeight), maxHeight).rounded(.down)

        if self.newHeight != clamped {
            frame.size = CGSizeMake(frame.size.width, clamped)
            invalidateIntrinsicContentHeight(clamped)
            if updateBindingNow {
                self.height.wrappedValue = clamped
            } else {
                DispatchQueue.main.async {
                    self.height.wrappedValue = clamped
                }
            }
        }
    }

    func updateFont() {
        let newFont = isShortEmoji(self.text)
        ? (self.text.count < 4 ? largeEmojiUIFont : mediumEmojiUIFont)
        : UIFont.preferredFont(forTextStyle: .body)
        if self.font != newFont {
            self.font = newFont
            // force apply new font because it has problem with doing it when the field had two emojis
            if self.text.count == 0 {
                self.text = " "
                self.text = ""
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeight()
    }

    override var intrinsicContentSize: CGSize {
        CGSizeMake(0, newHeight)
    }

    func setOnTextChangedListener(onTextChanged: @escaping (String, [UploadContent]) -> Void) {
        self.onTextChanged = onTextChanged
    }

    func setPlaceholderView() {
        placeholderLabel.textColor = UIColor(
            white: PXNativeTextEditorConfig.placeholderColorWhite,
            alpha: PXNativeTextEditorConfig.placeholderAlpha
        )
        placeholderLabel.font = UIFont.monospacedSystemFont(
            ofSize: PXNativeTextEditorConfig.placeholderFontSize,
            weight: PXNativeTextEditorConfig.placeholderMonoWeight
        )
        placeholderLabel.isHidden = !text.isEmpty
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PXNativeTextEditorConfig.placeholderLeadingInset),
            placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: PXNativeTextEditorConfig.placeholderTrailingInset),
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: PXNativeTextEditorConfig.placeholderTopInset)
        ])
    }

    func setOnFocusChangedListener(onFocusChanged: @escaping (Bool) -> Void) {
        self.onFocusChanged = onFocusChanged
    }

    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        if !UIPasteboard.general.hasImages { return UIMenu(children: suggestedActions)}
        return UIMenu(children: suggestedActions.map { elem in
            if let elem = elem as? UIMenu {
                var actions = elem.children
                // Replacing Paste action since it allows to paste animated images too
                let pasteIndex = elem.children.firstIndex { elem in elem.debugDescription.contains("Action: paste:")}
                if let pasteIndex = pasteIndex {
                    let paste = actions[pasteIndex]
                    actions.remove(at: pasteIndex)
                    let newPaste = UIAction(title: paste.title, image: paste.image) { action in
                        var images: [UploadContent] = []
                        var totalImages = 0
                        var processed = 0
                        let syncQueue = DispatchQueue(label: PXNativeTextEditorConfig.pxSyncQueueLabel)
                        UIPasteboard.general.itemProviders.forEach { p in
                            if p.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                                syncQueue.sync { totalImages += 1 }
                                p.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                                    var done = false
                                    var currentImages: [UploadContent] = []
                                    syncQueue.sync {
                                        processed += 1
                                        if let url = url, let image = UploadContent.loadFromURL(url: url) {
                                            images.append(image)
                                        }
                                        done = (processed == totalImages)
                                        currentImages = images
                                    }
                                    DispatchQueue.main.async {
                                        if !currentImages.isEmpty {
                                            self.onTextChanged(textView.text, currentImages)
                                        }
                                        // No images were found, just paste the text then
                                        if done && currentImages.isEmpty {
                                            textView.paste(UIPasteboard.general.string)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    actions.insert(newPaste, at: 0)
                }
                return UIMenu(title: elem.title, subtitle: elem.subtitle, image: elem.image, identifier: elem.identifier, options: elem.options, children: actions)
            } else {
                return elem
            }
        })
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !text.isEmpty
        if textView.markedTextRange == nil {
            var images: [UploadContent] = []
            var rangeDiff = 0
            let newAttributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            textView.attributedText.enumerateAttribute(
                NSAttributedString.Key.attachment,
                in: NSRange(location: 0, length: textView.attributedText.length),
                options: [],
                using: { value, range, _ in
                    if let attachment = (value as? NSTextAttachment)?.fileWrapper?.regularFileContents {
                        if let image = UIImage(data: attachment) {
                            images.append(.animatedImage(image: image))
                        } else if let img = (value as? NSTextAttachment)?.image {
                            images.append(.simpleImage(image: img))
                        }
                        newAttributedText.replaceCharacters(in: NSMakeRange(range.location - rangeDiff, range.length), with: "")
                        rangeDiff += range.length
                    }
                }
            )
            if textView.attributedText != newAttributedText {
                textView.attributedText = newAttributedText
            }
            onTextChanged(textView.text, images)
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        onFocusChanged(true)
        pxUpdateSelectedRange(textView)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        onFocusChanged(false)
        pxUpdateSelectedRange(textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        pxUpdateSelectedRange(textView)
    }

    private func pxUpdateSelectedRange(_ textView: UITextView) {
        let range = textView.selectedRange
        guard parent?.selectedRange != range else { return }
        DispatchQueue.main.async { [weak self] in
            self?.parent?.selectedRange = range
        }
    }
}

struct NativeTextEditor_Previews: PreviewProvider{
    static var previews: some View {
        NativeTextEditor(
            text: Binding.constant("Hello, world!"),
            disableEditing: Binding.constant(false),
            height: Binding.constant(100),
            focused: Binding.constant(false),
            lastUnfocusedDate: Binding.constant(.now),
            placeholder: Binding.constant("Placeholder"),
            selectedRange: Binding.constant(NSRange(location: 0, length: 0)),
            onImagesAdded: { _ in },
            colorScheme: .light
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - POPOPX
extension NativeTextEditor {
    static let pxComponentTag: String = PXNativeTextEditorConfig.componentTag
    static let pxMinHeight: CGFloat = PXNativeTextEditorConfig.minHeight
    static let pxMaxAbsoluteHeight: CGFloat = PXNativeTextEditorConfig.maxAbsoluteHeight
}
