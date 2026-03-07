import AppKit
import PDFKit
import Vision

/// Custom PDFView subclass that supports Word-like click-to-edit text.
/// Detects original font from PDF and preserves it in the replacement.
class EditablePDFView: PDFView {

    var isEditModeActive = false
    var onTextEditRequested: ((_ page: PDFPage, _ bounds: CGRect, _ text: String, _ pageIndex: Int) -> Void)?

    private var editTextView: NSTextView?
    private var editContainerView: NSView?

    // Currently editing
    private var editingPage: PDFPage?
    private var editingBounds: CGRect = .zero
    private var editingOriginalText: String = ""
    private var detectedFont: NSFont = NSFont.systemFont(ofSize: 12)
    private var detectedFontColor: NSColor = .black
    private var detectedAlignment: NSTextAlignment = .left

    // Highlight box shown on hover
    private var hoverHighlight: NSView?
    private var lastHoverPage: PDFPage?
    private var lastHoverBounds: CGRect = .zero

    // Throttle hover detection to avoid excessive computation
    private var lastHoverTime: TimeInterval = 0
    private let hoverThrottleInterval: TimeInterval = 0.05 // 50ms

    // MARK: - Cursor

    override func cursorUpdate(with event: NSEvent) {
        if isEditModeActive {
            // Use fast detection only (line/word) for cursor - no expensive scans
            let viewPoint = convert(event.locationInWindow, from: nil)
            if let page = page(for: viewPoint, nearest: false) {
                let pagePoint = convert(viewPoint, to: page)
                if fastTextHitTest(at: pagePoint, on: page) {
                    NSCursor.iBeam.set()
                    return
                }
            }
            NSCursor.arrow.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isEditModeActive {
            addCursorRect(bounds, cursor: .iBeam)
        }
    }

    // MARK: - Mouse Tracking

    override func updateTrackingAreas() {
        // Only remove tracking areas we own (tagged with our userInfo)
        for area in trackingAreas where area.owner === self && area.userInfo?["editMode"] != nil {
            removeTrackingArea(area)
        }
        super.updateTrackingAreas()
        if isEditModeActive {
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect, .cursorUpdate],
                owner: self,
                userInfo: ["editMode": true]
            )
            addTrackingArea(area)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard isEditModeActive, editTextView == nil else {
            if editTextView == nil { hideHoverHighlight() }
            super.mouseMoved(with: event)
            return
        }

        // Throttle hover detection for smooth performance
        let now = CACurrentMediaTime()
        guard now - lastHoverTime >= hoverThrottleInterval else { return }
        lastHoverTime = now

        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: false) else {
            hideHoverHighlight()
            return
        }

        let pagePoint = convert(viewPoint, to: page)

        // Use fast detection for hover (line + word only, no area scanning)
        if let selection = fastFindTextBlock(at: pagePoint, on: page) {
            let text = selection.string ?? ""
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let bounds = selection.bounds(for: page)
                showHoverHighlight(for: page, bounds: bounds)
                NSCursor.iBeam.set()
                return
            }
        }

        hideHoverHighlight()
        NSCursor.arrow.set()
    }

    // MARK: - Mouse Click

    override func mouseDown(with event: NSEvent) {
        guard isEditModeActive else {
            super.mouseDown(with: event)
            return
        }

        if editTextView != nil {
            commitEdit()
        }

        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: false) else {
            super.mouseDown(with: event)
            return
        }

        let pagePoint = convert(viewPoint, to: page)

        // On click, use thorough detection (includes area scanning + offset probing)
        if let selection = thoroughFindTextBlock(at: pagePoint, on: page) {
            let text = selection.string ?? ""
            let bounds = selection.bounds(for: page)

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                super.mouseDown(with: event)
                return
            }

            editingPage = page
            editingBounds = bounds
            editingOriginalText = text

            // Detect original font attributes from PDF
            detectFontAttributes(selection: selection, page: page)

            hideHoverHighlight()

            if let doc = document {
                let pageIndex = doc.index(for: page)
                onTextEditRequested?(page, bounds, text, pageIndex)
            }

            showInlineEditor(for: page, bounds: bounds, text: text)
        } else {
            super.mouseDown(with: event)
        }
    }

    // MARK: - Scroll/Zoom observation (cleanup stale overlays)

    override func layout() {
        super.layout()
        // When layout changes (zoom/scroll), remove stale hover highlight
        hideHoverHighlight()
        // Reposition editor if active
        repositionEditor()
    }

    // MARK: - Text Detection (Fast vs Thorough)

    /// Fast hit test: just check if there's text at point (for cursor/hover)
    private func fastTextHitTest(at point: CGPoint, on page: PDFPage) -> Bool {
        if let sel = page.selectionForLine(at: point), let text = sel.string,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let sel = page.selectionForWord(at: point), let text = sel.string,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }

    /// Fast detection: line or word only (used for mouseMoved hover)
    private func fastFindTextBlock(at point: CGPoint, on page: PDFPage) -> PDFSelection? {
        if let selection = page.selectionForLine(at: point) {
            let text = selection.string ?? ""
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return selection
            }
        }
        if let selection = page.selectionForWord(at: point) {
            let text = selection.string ?? ""
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return selection
            }
        }
        return nil
    }

    /// Thorough detection: line → word → area scan → offset probing (used on click)
    private func thoroughFindTextBlock(at point: CGPoint, on page: PDFPage) -> PDFSelection? {
        // 1. Fast path first
        if let selection = fastFindTextBlock(at: point, on: page) {
            return selection
        }

        // 2. Area selection around click point (helps with table cells)
        let scanRadii: [CGFloat] = [8, 16, 30]
        for radius in scanRadii {
            let topLeft = CGPoint(x: point.x - radius, y: point.y - radius)
            let bottomRight = CGPoint(x: point.x + radius, y: point.y + radius)
            if let selection = page.selection(from: topLeft, to: bottomRight) {
                let text = selection.string ?? ""
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return selection
                }
            }
        }

        // 3. Offset probing (some PDF text has shifted hit areas)
        let offsets: [(CGFloat, CGFloat)] = [
            (0, 5), (0, -5), (5, 0), (-5, 0),
            (0, 10), (0, -10), (10, 0), (-10, 0)
        ]
        for (dx, dy) in offsets {
            let offsetPoint = CGPoint(x: point.x + dx, y: point.y + dy)
            if let sel = page.selectionForLine(at: offsetPoint) {
                let text = sel.string ?? ""
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return sel
                }
            }
        }

        return nil
    }

    // MARK: - Font Detection

    /// Extract font name, size, color from the PDF selection's attributed string
    private func detectFontAttributes(selection: PDFSelection, page: PDFPage) {
        guard let attrStr = selection.attributedString, attrStr.length > 0 else {
            let fontSize = estimateFontSize(lineHeight: editingBounds.height)
            detectedFont = NSFont.systemFont(ofSize: fontSize)
            detectedFontColor = .black
            detectedAlignment = .left
            return
        }

        let attrs = attrStr.attributes(at: 0, effectiveRange: nil)

        // Font
        if let font = attrs[.font] as? NSFont {
            let text = selection.string ?? ""
            let lineCount = max(CGFloat(text.components(separatedBy: .newlines).count), 1)
            let expectedLineHeight = editingBounds.height / lineCount
            let maxReasonableSize = expectedLineHeight * 1.1

            if font.pointSize > 0 && font.pointSize <= maxReasonableSize {
                detectedFont = font
            } else {
                let estimatedSize = estimateFontSize(lineHeight: expectedLineHeight)
                detectedFont = NSFont(name: font.fontName, size: estimatedSize) ??
                               NSFont.systemFont(ofSize: estimatedSize)
            }
        } else {
            let fontSize = estimateFontSize(lineHeight: editingBounds.height)
            detectedFont = NSFont.systemFont(ofSize: fontSize)
        }

        // Color
        detectedFontColor = (attrs[.foregroundColor] as? NSColor) ?? .black

        // Alignment
        if let para = attrs[.paragraphStyle] as? NSParagraphStyle {
            detectedAlignment = para.alignment
        } else {
            detectedAlignment = .left
        }
    }

    private func estimateFontSize(lineHeight: CGFloat) -> CGFloat {
        let estimated = lineHeight / 1.2
        return max(min(estimated, 72), 6)
    }

    /// Find closest matching system font for annotation use
    private func fontForAnnotation() -> NSFont {
        let size = detectedFont.pointSize
        let fontName = detectedFont.fontName

        // Try exact font
        if let exactFont = NSFont(name: fontName, size: size) {
            return exactFont
        }

        // Try family with traits
        let familyName = detectedFont.familyName ?? "Helvetica"
        let traits = NSFontManager.shared.traits(of: detectedFont)
        if let familyFont = NSFontManager.shared.font(
            withFamily: familyName, traits: traits,
            weight: NSFontManager.shared.weight(of: detectedFont), size: size
        ) {
            return familyFont
        }

        // PDF font name mapping fallbacks
        let fontMap: [String: String] = [
            "TimesNewRoman": "Times-Roman", "Times-Roman": "Times-Roman",
            "ArialMT": "Helvetica", "Arial": "Helvetica",
            "CourierNew": "Courier", "Courier-": "Courier",
            "Calibri": "Helvetica", "Cambria": "Times-Roman",
            "Verdana": "Verdana", "Georgia": "Georgia",
            "Tahoma": "Geneva",
        ]
        for (key, mapped) in fontMap {
            if fontName.contains(key), let f = NSFont(name: mapped, size: size) {
                return f
            }
        }

        return NSFont.systemFont(ofSize: size)
    }

    // MARK: - Hover Highlight

    private func showHoverHighlight(for page: PDFPage, bounds pageBounds: CGRect) {
        if lastHoverPage === page && lastHoverBounds == pageBounds { return }
        lastHoverPage = page
        lastHoverBounds = pageBounds

        hideHoverHighlight()

        let viewRect = convert(pageBounds, from: page)

        let highlight = NSView(frame: viewRect)
        highlight.wantsLayer = true
        highlight.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.06).cgColor
        highlight.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.25).cgColor
        highlight.layer?.borderWidth = 1
        highlight.layer?.cornerRadius = 1

        if let documentView = documentView {
            let docRect = documentView.convert(viewRect, from: self)
            highlight.frame = docRect
            documentView.addSubview(highlight)
        } else {
            addSubview(highlight)
        }

        hoverHighlight = highlight
    }

    private func hideHoverHighlight() {
        hoverHighlight?.removeFromSuperview()
        hoverHighlight = nil
        lastHoverPage = nil
        lastHoverBounds = .zero
    }

    // MARK: - Inline Editor

    private func showInlineEditor(for page: PDFPage, bounds pageBounds: CGRect, text: String) {
        editTextView?.removeFromSuperview()
        editContainerView?.removeFromSuperview()

        let viewRect = convert(pageBounds, from: page)
        let padding: CGFloat = 2
        let editorRect = viewRect.insetBy(dx: -padding, dy: -padding)

        // Scale the detected font size for the view (PDF points → screen pixels)
        let viewFontSize = max(detectedFont.pointSize * scaleFactor, 8)
        let viewFont: NSFont
        if let scaled = NSFont(name: detectedFont.fontName, size: viewFontSize) {
            viewFont = scaled
        } else {
            viewFont = NSFont.systemFont(ofSize: viewFontSize)
        }

        // Container
        let container = NSView(frame: editorRect)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.cgColor
        container.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
        container.layer?.borderWidth = 1.5
        container.layer?.cornerRadius = 2

        // NSTextView for editing
        let textStorage = NSTextStorage(string: text, attributes: [
            .font: viewFont,
            .foregroundColor: detectedFontColor
        ])
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(
            width: editorRect.width - padding * 2,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: NSRect(
            x: padding, y: padding,
            width: editorRect.width - padding * 2,
            height: editorRect.height - padding * 2
        ), textContainer: textContainer)

        textView.font = viewFont
        textView.textColor = detectedFontColor
        textView.backgroundColor = NSColor.white
        textView.drawsBackground = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isFieldEditor = false
        textView.allowsUndo = true
        textView.delegate = self
        textView.alignment = detectedAlignment
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: editorRect.width - padding * 2, height: 500)
        textView.textContainerInset = NSSize(width: 0, height: 0)

        container.addSubview(textView)

        if let documentView = documentView {
            let docRect = documentView.convert(editorRect, from: self)
            container.frame = docRect
            textView.frame = NSRect(
                x: padding, y: padding,
                width: docRect.width - padding * 2,
                height: docRect.height - padding * 2
            )
            documentView.addSubview(container)
        } else {
            addSubview(container)
        }

        editTextView = textView
        editContainerView = container

        textView.window?.makeFirstResponder(textView)
        textView.selectAll(nil)
    }

    /// Reposition the editor overlay when zoom/scroll changes
    private func repositionEditor() {
        guard let page = editingPage, editContainerView != nil else { return }
        let viewRect = convert(editingBounds, from: page)
        let padding: CGFloat = 2
        let editorRect = viewRect.insetBy(dx: -padding, dy: -padding)

        if let documentView = documentView {
            let docRect = documentView.convert(editorRect, from: self)
            editContainerView?.frame = docRect
            editTextView?.frame = NSRect(
                x: padding, y: padding,
                width: docRect.width - padding * 2,
                height: docRect.height - padding * 2
            )
        }
    }

    // MARK: - Commit / Cancel

    func commitEdit() {
        guard let textView = editTextView, let page = editingPage else {
            cleanupEditor()
            return
        }

        let newText = textView.string
        let bounds = editingBounds

        if newText != editingOriginalText && !newText.isEmpty {
            let annotFont = fontForAnnotation()

            // Cover original text with white rectangle - expand to fully cover
            let coverPadding: CGFloat = 2.0
            let coverBounds = bounds.insetBy(dx: -coverPadding, dy: -coverPadding)
            let coverAnnotation = PDFAnnotation(bounds: coverBounds, forType: .square, withProperties: nil)
            coverAnnotation.color = NSColor.white
            coverAnnotation.interiorColor = NSColor.white
            let border = PDFBorder()
            border.lineWidth = 0
            coverAnnotation.border = border
            coverAnnotation.contents = "__EDIT_COVER__"
            page.addAnnotation(coverAnnotation)

            // Compensate for freeText internal padding
            let freeTextInset: CGFloat = 2.0
            let textBounds = CGRect(
                x: bounds.origin.x - freeTextInset,
                y: bounds.origin.y - freeTextInset,
                width: bounds.width + freeTextInset * 2,
                height: bounds.height + freeTextInset * 2
            )

            let textAnnotation = PDFAnnotation(bounds: textBounds, forType: .freeText, withProperties: nil)
            textAnnotation.contents = newText
            textAnnotation.font = annotFont
            textAnnotation.fontColor = detectedFontColor
            textAnnotation.color = .clear
            textAnnotation.alignment = detectedAlignment
            let textBorder = PDFBorder()
            textBorder.lineWidth = 0
            textAnnotation.border = textBorder
            page.addAnnotation(textAnnotation)

            // BUGFIX: Mark document as having unsaved changes
            NotificationCenter.default.post(name: .init("AcroromiEditCommitted"), object: nil)
        }

        cleanupEditor()
    }

    func cancelEdit() {
        cleanupEditor()
    }

    private func cleanupEditor() {
        editTextView?.removeFromSuperview()
        editTextView = nil
        editContainerView?.removeFromSuperview()
        editContainerView = nil
        editingPage = nil
        editingBounds = .zero
        editingOriginalText = ""
        // Reset detected attributes so they don't leak to next edit
        detectedFont = NSFont.systemFont(ofSize: 12)
        detectedFontColor = .black
        detectedAlignment = .left
    }
}

// MARK: - NSTextViewDelegate

extension EditablePDFView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelEdit()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSEvent.modifierFlags.contains(.shift) {
                return false // Allow Shift+Enter for newline
            }
            commitEdit()
            return true
        }
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            commitEdit()
            return true
        }
        return false
    }
}
