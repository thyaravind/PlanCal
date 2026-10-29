import SwiftUI
import WebKit

#if os(macOS)
import AppKit
#endif

struct RichMarkdownEditor: View {
    @Binding var markdown: String
    let placeholder: String
    var minHeight: CGFloat = 190
    var onFocusChanged: (Bool) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme
    @State private var commandRequest: MarkdownEditorCommandRequest?
    @State private var isEditingLink = false
    @State private var linkDestination = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            formattingBar

            editorSurface
            .frame(minHeight: minHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityLabel("Markdown note")
        }
    }

    @ViewBuilder
    private var editorSurface: some View {
        #if os(macOS)
        ZStack(alignment: .topLeading) {
            NativeMarkdownTextView(
                configuration: NativeMarkdownConfiguration(
                    markdown: $markdown,
                    colorScheme: colorScheme,
                    commandRequest: commandRequest,
                    onFocusChanged: onFocusChanged
                )
            )

            if markdown.isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
        }
        #else
        CodeMirrorMarkdownView(
            configuration: CodeMirrorConfiguration(
                markdown: $markdown,
                placeholder: placeholder,
                colorScheme: colorScheme,
                commandRequest: commandRequest,
                onRequestLink: { isEditingLink = true },
                onFocusChanged: onFocusChanged
            )
        )
        #endif
    }

    private var formattingBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 5) {
                Menu {
                    Button { send(.heading(0)) } label: {
                        PlancalNativeIconLabel(title: "Text", icon: .text)
                    }
                    Button { send(.heading(1)) } label: {
                        PlancalNativeIconLabel(title: "Heading 1", icon: .heading1)
                    }
                    Button { send(.heading(2)) } label: {
                        PlancalNativeIconLabel(title: "Heading 2", icon: .heading2)
                    }
                    Button { send(.heading(3)) } label: {
                        PlancalNativeIconLabel(title: "Heading 3", icon: .heading3)
                    }
                } label: {
                    PlancalNativeIconLabel(title: "Text", icon: .text, size: 16)
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .plancalHoverEffect(scale: 1.025)
                .help("Choose a text style, or type #, ##, or ### followed by a space")

                Menu {
                    ForEach(MarkdownLetterCase.allCases) { letterCase in
                        Button(letterCase.title) {
                            send(.changeCase(letterCase))
                        }
                    }
                } label: {
                    PlancalNativeGlyph(icon: .letterCase, size: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
                .menuIndicator(.hidden)
                .plancalHoverEffect(scale: 1.08)
                .accessibilityLabel("Change case")
                .help("Change the casing of selected text")

                Divider()
                    .frame(height: 22)
                    .padding(.horizontal, 3)

                formatButton("Bold", icon: .bold, command: .bold)
                formatButton("Italic", icon: .italic, command: .italic)
                formatButton("Strikethrough", icon: .strikethrough, command: .strikethrough)
                formatButton("Inline code", icon: .code, command: .inlineCode)

                Button {
                    isEditingLink = true
                } label: {
                    PlancalGlyph(icon: .link, size: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
                .plancalHoverEffect(scale: 1.08)
                .accessibilityLabel("Link")
                .popover(isPresented: $isEditingLink, arrowEdge: .bottom) {
                    linkEditor
                }

                Divider()
                    .frame(height: 22)
                    .padding(.horizontal, 3)

                formatButton("Bulleted list", icon: .bulletedList, command: .bulletList)
                formatButton("Numbered list", icon: .numberedList, command: .orderedList)
                formatButton("Checklist", icon: .checklist, command: .taskList)
                formatButton("Quote", icon: .quote, command: .blockquote)
                formatButton("Code block", icon: .code, command: .codeBlock)
            }
            .padding(6)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var linkEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Link destination")
                .font(.headline)
            TextField("https://example.com", text: $linkDestination)
                .textFieldStyle(.roundedBorder)
                .onSubmit { applyLink() }
            HStack {
                Button("Cancel") {
                    isEditingLink = false
                    linkDestination = ""
                }
                Spacer()
                Button("Apply") { applyLink() }
                    .buttonStyle(.glassProminent)
                    .disabled(linkDestination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func formatButton(
        _ title: String,
        icon: PlancalIcon,
        command: MarkdownEditorCommand
    ) -> some View {
        Button {
            send(command)
        } label: {
            PlancalGlyph(icon: icon, size: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(width: 30, height: 30)
        .contentShape(Circle())
        .plancalHoverEffect(scale: 1.08)
        .accessibilityLabel(title)
    }

    private func applyLink() {
        let destination = linkDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else { return }

        let normalized: String
        if URL(string: destination)?.scheme != nil {
            normalized = destination
        } else {
            normalized = "https://\(destination)"
        }

        send(.link(normalized))
        isEditingLink = false
        linkDestination = ""
    }

    private func send(_ command: MarkdownEditorCommand) {
        commandRequest = MarkdownEditorCommandRequest(command: command)
    }
}

private struct MarkdownEditorCommandRequest {
    let id = UUID()
    let command: MarkdownEditorCommand
}

enum MarkdownLetterCase: String, CaseIterable, Identifiable {
    case lowercase
    case uppercase
    case title

    var id: Self { self }

    var title: String {
        switch self {
        case .lowercase:
            "lowercase"
        case .uppercase:
            "UPPERCASE"
        case .title:
            "Title Case"
        }
    }

    nonisolated func transform(_ text: String) -> String {
        switch self {
        case .lowercase:
            text.lowercased()
        case .uppercase:
            text.uppercased()
        case .title:
            Self.titleCase(text)
        }
    }

    nonisolated private static func titleCase(_ text: String) -> String {
        var result = ""
        var beginsWord = true

        for character in text.lowercased() {
            let fragment = String(character)
            let isAlphanumeric = fragment.rangeOfCharacter(from: .alphanumerics) != nil

            if isAlphanumeric, beginsWord {
                result.append(contentsOf: fragment.uppercased())
            } else {
                result.append(contentsOf: fragment)
            }
            beginsWord = !isAlphanumeric
        }

        return result
    }
}

private enum MarkdownEditorCommand {
    case focus
    case bold
    case italic
    case strikethrough
    case inlineCode
    case heading(Int)
    case bulletList
    case orderedList
    case taskList
    case blockquote
    case codeBlock
    case link(String)
    case changeCase(MarkdownLetterCase)

    var payload: [String: Any] {
        switch self {
        case .focus:
            ["name": "focus"]
        case .bold:
            ["name": "bold"]
        case .italic:
            ["name": "italic"]
        case .strikethrough:
            ["name": "strikethrough"]
        case .inlineCode:
            ["name": "inlineCode"]
        case .heading(let level):
            ["name": "heading", "value": level]
        case .bulletList:
            ["name": "bulletList"]
        case .orderedList:
            ["name": "orderedList"]
        case .taskList:
            ["name": "taskList"]
        case .blockquote:
            ["name": "blockquote"]
        case .codeBlock:
            ["name": "codeBlock"]
        case .link(let destination):
            ["name": "link", "value": destination]
        case .changeCase(let letterCase):
            ["name": "changeCase", "value": letterCase.rawValue]
        }
    }
}

#if os(macOS)
private struct NativeMarkdownConfiguration {
    var markdown: Binding<String>
    var colorScheme: ColorScheme
    var commandRequest: MarkdownEditorCommandRequest?
    var onFocusChanged: (Bool) -> Void
}

private final class NativeMarkdownScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let textView = documentView as? NSTextView else { return }

        let viewportSize = contentSize
        textView.minSize = viewportSize
        if textView.frame.width != viewportSize.width
            || textView.frame.height < viewportSize.height {
            textView.setFrameSize(
                NSSize(
                    width: viewportSize.width,
                    height: max(textView.frame.height, viewportSize.height)
                )
            )
        }
    }
}

private struct NativeMarkdownTextView: NSViewRepresentable {
    var configuration: NativeMarkdownConfiguration

    func makeCoordinator() -> NativeMarkdownCoordinator {
        NativeMarkdownCoordinator(configuration: configuration)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NativeMarkdownScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView(
            frame: NSRect(x: 0, y: 0, width: 1, height: 240)
        )
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 240)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 18, height: 16)
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.string = configuration.markdown.wrappedValue

        scrollView.documentView = textView
        context.coordinator.connect(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(configuration: configuration)
    }
}

@MainActor
private final class NativeMarkdownCoordinator: NSObject, NSTextViewDelegate {
    private var configuration: NativeMarkdownConfiguration
    private weak var textView: NSTextView?
    private var lastCommandID: UUID?
    private var isApplyingExternalUpdate = false

    init(configuration: NativeMarkdownConfiguration) {
        self.configuration = configuration
    }

    func connect(to textView: NSTextView) {
        self.textView = textView
        applyPresentation(to: textView)
    }

    func update(configuration: NativeMarkdownConfiguration) {
        self.configuration = configuration
        guard let textView else { return }

        let externalMarkdown = configuration.markdown.wrappedValue
        if textView.string != externalMarkdown {
            let selectedRange = textView.selectedRange()
            isApplyingExternalUpdate = true
            textView.string = externalMarkdown
            textView.setSelectedRange(
                NSRange(
                    location: min(selectedRange.location, textView.string.utf16.count),
                    length: 0
                )
            )
            isApplyingExternalUpdate = false
        }

        applyPresentation(to: textView)

        if let request = configuration.commandRequest,
           request.id != lastCommandID {
            lastCommandID = request.id
            perform(request.command, in: textView)
        }
    }

    func textDidBeginEditing(_ notification: Notification) {
        configuration.onFocusChanged(true)
    }

    func textDidEndEditing(_ notification: Notification) {
        configuration.onFocusChanged(false)
    }

    func textDidChange(_ notification: Notification) {
        guard !isApplyingExternalUpdate, let textView else { return }
        if configuration.markdown.wrappedValue != textView.string {
            configuration.markdown.wrappedValue = textView.string
        }
        applyPresentation(to: textView)
    }

    private func applyPresentation(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        let fullRange = NSRange(location: 0, length: storage.length)
        let baseFont = NSFont.systemFont(ofSize: 15.5)
        let textColor = NSColor.labelColor
        let markerColor = NSColor.tertiaryLabelColor
        let codeBackground = NSColor.controlAccentColor.withAlphaComponent(
            configuration.colorScheme == .dark ? 0.2 : 0.1
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 3

        storage.beginEditing()
        storage.setAttributes(
            [
                .font: baseFont,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ],
            range: fullRange
        )

        applyRegex(#"(?m)^(#{1,3})[ \t]+(.+)$"#, to: storage) { match in
            let markerRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let level = markerRange.length
            let size: CGFloat = switch level {
            case 1: 28
            case 2: 23
            default: 19
            }
            storage.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: size, weight: .bold),
                    .foregroundColor: textColor
                ],
                range: contentRange
            )
            storage.addAttribute(.foregroundColor, value: markerColor, range: markerRange)
        }

        applyRegex(#"\*([^*\n]+)\*"#, to: storage) { match in
            let range = match.range(at: 1)
            storage.addAttribute(
                .font,
                value: NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask),
                range: range
            )
        }
        applyRegex(#"\*\*([^*\n]+)\*\*"#, to: storage) { match in
            storage.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: 15.5, weight: .bold),
                range: match.range(at: 1)
            )
        }
        applyRegex(#"~~([^~\n]+)~~"#, to: storage) { match in
            storage.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: match.range(at: 1)
            )
        }
        applyRegex(#"`([^`\n]+)`"#, to: storage) { match in
            let range = match.range(at: 1)
            storage.addAttributes(
                [
                    .font: NSFont.monospacedSystemFont(ofSize: 14.5, weight: .regular),
                    .backgroundColor: codeBackground
                ],
                range: range
            )
        }
        applyRegex(#"(?m)^>[ \t]?(.*)$"#, to: storage) { match in
            storage.addAttributes(
                [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                ],
                range: match.range(at: 1)
            )
        }

        storage.endEditing()

        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .controlAccentColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ]
        textView.typingAttributes = [
            .font: baseFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let clampedLocation = min(selection.location, storage.length)
        let clampedLength = min(selection.length, storage.length - clampedLocation)
        textView.setSelectedRange(
            NSRange(location: clampedLocation, length: clampedLength)
        )
    }

    private func applyRegex(
        _ pattern: String,
        to storage: NSTextStorage,
        apply: (NSTextCheckingResult) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: storage.length)
        regex.enumerateMatches(in: storage.string, range: range) { match, _, _ in
            guard let match else { return }
            apply(match)
        }
    }

    private func perform(_ command: MarkdownEditorCommand, in textView: NSTextView) {
        switch command {
        case .focus:
            textView.window?.makeFirstResponder(textView)
        case .bold:
            wrapSelection(in: textView, prefix: "**", suffix: "**")
        case .italic:
            wrapSelection(in: textView, prefix: "*", suffix: "*")
        case .strikethrough:
            wrapSelection(in: textView, prefix: "~~", suffix: "~~")
        case .inlineCode:
            wrapSelection(in: textView, prefix: "`", suffix: "`")
        case .heading(let level):
            applyBlockStyle(.heading(level), in: textView)
        case .bulletList:
            applyBlockStyle(.bulletList, in: textView)
        case .orderedList:
            applyBlockStyle(.orderedList, in: textView)
        case .taskList:
            applyBlockStyle(.taskList, in: textView)
        case .blockquote:
            applyBlockStyle(.blockquote, in: textView)
        case .codeBlock:
            wrapSelection(in: textView, prefix: "```\n", suffix: "\n```")
        case .link(let destination):
            let selection = textView.selectedRange()
            if selection.length == 0 {
                replaceSelection(
                    in: textView,
                    with: "[text](\(destination))",
                    selectedOffset: 1,
                    selectedLength: 4
                )
            } else {
                wrapSelection(
                    in: textView,
                    prefix: "[",
                    suffix: "](\(destination))"
                )
            }
        case .changeCase(let letterCase):
            changeCase(letterCase, in: textView)
        }
    }

    private func changeCase(_ letterCase: MarkdownLetterCase, in textView: NSTextView) {
        let range = textView.selectedRange()
        guard range.length > 0 else {
            textView.window?.makeFirstResponder(textView)
            return
        }

        let selectedText = (textView.string as NSString).substring(with: range)
        let replacement = letterCase.transform(selectedText)
        guard replacement != selectedText else {
            textView.window?.makeFirstResponder(textView)
            return
        }

        replaceSelection(
            in: textView,
            with: replacement,
            selectedOffset: 0,
            selectedLength: replacement.utf16.count
        )
    }

    private func wrapSelection(
        in textView: NSTextView,
        prefix: String,
        suffix: String
    ) {
        let range = textView.selectedRange()
        let selectedText = (textView.string as NSString).substring(with: range)
        replaceSelection(
            in: textView,
            with: prefix + selectedText + suffix,
            selectedOffset: prefix.utf16.count,
            selectedLength: range.length
        )
    }

    private func replaceSelection(
        in textView: NSTextView,
        with replacement: String,
        selectedOffset: Int,
        selectedLength: Int
    ) {
        let range = textView.selectedRange()
        textView.textStorage?.replaceCharacters(in: range, with: replacement)
        textView.setSelectedRange(
            NSRange(
                location: range.location + selectedOffset,
                length: selectedLength
            )
        )
        commitChange(in: textView)
    }

    private func applyBlockStyle(
        _ style: MarkdownBlockStyle,
        in textView: NSTextView
    ) {
        let selection = textView.selectedRange()
        let source = textView.string as NSString
        let effectiveSelection = selection.length > 0
            ? NSRange(location: selection.location, length: selection.length - 1)
            : selection
        let lineRange = source.lineRange(for: effectiveSelection)
        let selectedLines = source.substring(with: lineRange)
        let replacement = MarkdownBlockFormatter.transform(selectedLines, to: style)

        guard replacement != selectedLines else {
            textView.window?.makeFirstResponder(textView)
            return
        }

        textView.textStorage?.replaceCharacters(in: lineRange, with: replacement)
        textView.setSelectedRange(
            NSRange(location: lineRange.location, length: replacement.utf16.count)
        )
        commitChange(in: textView)
    }

    private func commitChange(in textView: NSTextView) {
        if configuration.markdown.wrappedValue != textView.string {
            configuration.markdown.wrappedValue = textView.string
        }
        applyPresentation(to: textView)
        textView.window?.makeFirstResponder(textView)
    }
}
#endif

private struct CodeMirrorConfiguration {
    var markdown: Binding<String>
    var placeholder: String
    var colorScheme: ColorScheme
    var commandRequest: MarkdownEditorCommandRequest?
    var onRequestLink: () -> Void
    var onFocusChanged: (Bool) -> Void
}

@MainActor
private final class CodeMirrorCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private(set) weak var webView: WKWebView?
    var configuration: CodeMirrorConfiguration

    private var isReady = false
    private var webMarkdown: String?
    private var lastPlaceholder: String?
    private var lastTheme: String?
    private var lastCommandID: UUID?

    init(configuration: CodeMirrorConfiguration) {
        self.configuration = configuration
    }

    func connect(to webView: WKWebView) {
        self.webView = webView
        let controller = webView.configuration.userContentController
        controller.add(self, name: "editorReady")
        controller.add(self, name: "markdownChanged")
        controller.add(self, name: "requestLink")
        controller.add(self, name: "focusChanged")

        guard let resourceURL = Bundle.main.url(forResource: "MarkdownEditor", withExtension: "html") else {
            webView.loadHTMLString(
                "<html><body style='font: -apple-system-body; color: #777'>Editor resource is unavailable.</body></html>",
                baseURL: nil
            )
            return
        }

        do {
            let html = try String(contentsOf: resourceURL, encoding: .utf8)
            webView.loadHTMLString(html, baseURL: resourceURL.deletingLastPathComponent())
        } catch {
            webView.loadHTMLString(
                "<html><body style='font: -apple-system-body; color: #777'>Editor resource could not be loaded.</body></html>",
                baseURL: nil
            )
        }
    }

    func disconnect() {
        guard let webView else { return }
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "editorReady")
        controller.removeScriptMessageHandler(forName: "markdownChanged")
        controller.removeScriptMessageHandler(forName: "requestLink")
        controller.removeScriptMessageHandler(forName: "focusChanged")
    }

    func update(configuration: CodeMirrorConfiguration) {
        self.configuration = configuration
        synchronizeIfReady()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "editorReady":
            isReady = true
            synchronizeIfReady()
        case "markdownChanged":
            guard let value = message.body as? String else { return }
            webMarkdown = value
            if configuration.markdown.wrappedValue != value {
                configuration.markdown.wrappedValue = value
            }
        case "requestLink":
            configuration.onRequestLink()
        case "focusChanged":
            guard let isFocused = message.body as? Bool else { return }
            configuration.onFocusChanged(isFocused)
        default:
            break
        }
    }

    private func synchronizeIfReady() {
        guard isReady, let webView else { return }

        let markdown = configuration.markdown.wrappedValue
        if webMarkdown != markdown {
            webMarkdown = markdown
            evaluate("window.plancalEditor?.setContent(\(jsonString(markdown)))", in: webView)
        }

        if lastPlaceholder != configuration.placeholder {
            lastPlaceholder = configuration.placeholder
            evaluate("window.plancalEditor?.setPlaceholder(\(jsonString(configuration.placeholder)))", in: webView)
        }

        let theme = configuration.colorScheme == .dark ? "dark" : "light"
        if lastTheme != theme {
            lastTheme = theme
            evaluate("window.plancalEditor?.setTheme(\(jsonString(theme)))", in: webView)
        }

        if let request = configuration.commandRequest, request.id != lastCommandID {
            guard let payload = jsonObject(request.command.payload) else { return }
            lastCommandID = request.id
            evaluate("window.plancalEditor?.command(\(payload))", in: webView)
        }
    }

    private func evaluate(_ script: String, in webView: WKWebView) {
        webView.evaluateJavaScript(script) { _, _ in }
    }

    private func jsonString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let result = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return result
    }

    private func jsonObject(_ value: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let result = String(data: data, encoding: .utf8) else {
            return nil
        }
        return result
    }
}

@MainActor
private func makeCodeMirrorWebView(coordinator: CodeMirrorCoordinator) -> WKWebView {
    let webConfiguration = WKWebViewConfiguration()
    webConfiguration.websiteDataStore = .nonPersistent()
    webConfiguration.defaultWebpagePreferences.allowsContentJavaScript = true

    let webView = WKWebView(frame: .zero, configuration: webConfiguration)
    webView.navigationDelegate = coordinator

    #if os(macOS)
    webView.allowsMagnification = false
    webView.underPageBackgroundColor = .clear
    #else
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    webView.scrollView.keyboardDismissMode = .interactive
    #endif

    coordinator.connect(to: webView)
    return webView
}

#if os(macOS)
private struct CodeMirrorMarkdownView: NSViewRepresentable {
    var configuration: CodeMirrorConfiguration

    func makeCoordinator() -> CodeMirrorCoordinator {
        CodeMirrorCoordinator(configuration: configuration)
    }

    func makeNSView(context: Context) -> WKWebView {
        makeCodeMirrorWebView(coordinator: context.coordinator)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(configuration: configuration)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: CodeMirrorCoordinator) {
        coordinator.disconnect()
    }
}
#else
private struct CodeMirrorMarkdownView: UIViewRepresentable {
    var configuration: CodeMirrorConfiguration

    func makeCoordinator() -> CodeMirrorCoordinator {
        CodeMirrorCoordinator(configuration: configuration)
    }

    func makeUIView(context: Context) -> WKWebView {
        makeCodeMirrorWebView(coordinator: context.coordinator)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(configuration: configuration)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: CodeMirrorCoordinator) {
        coordinator.disconnect()
    }
}
#endif
