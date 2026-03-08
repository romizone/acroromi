import AppKit
import PDFKit
import Vision
import QuartzCore

/// Custom PDFView subclass that supports Sejda-style smooth click-to-edit text.
/// Fixes: animation, hover lag, font detection, editor positioning, commit transitions.
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

    // Hover highlight
    private var hoverHighlight: NSView?
    private var lastHoverPage: PDFPage?
    private var lastHoverBounds: CGRect = .zero

    // Throttle hover - reduced to ~16ms (1 frame at 60fps) for smooth cursor
    private var lastHoverTime: TimeInterval = 0
    private let hoverThrottleInterval: TimeInterval = 0.016

    // Sejda-style colors
    private let editorBorderColor = NSColor(red: 0.016, green: 0.510, blue: 0.898, alpha: 0.7)
    private let editorShadowColor = NSColor(red: 0.016, green: 0.510, blue: 0.898, alpha: 0.15)
    private let hoverHighlightColor = NSColor(red: 0.016, green: 0.510, blue: 0.898, alpha: 0.05)
    private let hoverBorderColor = NSColor(red: 0.016, green: 0.510, blue: 0.898, alpha: 0.20)

    // MARK: - Cursor

    override func cursorUpdate(with event: NSEvent) {
        if isEditModeActive {
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
        guard isEditModeActive else {
            hideHoverHighlight()
            super.mouseMoved(with: event)
            return
        }

        // If editor is active, still update cursor for text areas but skip hover highlight
        if editTextView != nil {
            let viewPoint = convert(event.locationInWindow, from: nil)
            if let page = page(for: viewPoint, nearest: false) {
                let pagePoint = convert(viewPoint, to: page)
                if fastTextHitTest(at: pagePoint, on: page) {
                    NSCursor.iBeam.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            return
        }

        // Throttle hover detection — 16ms (1 frame)
        let now = CACurrentMediaTime()
        guard now - lastHoverTime >= hoverThrottleInterval else { return }
        lastHoverTime = now

        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: false) else {
            hideHoverHighlight()
            NSCursor.arrow.set()
            return
        }

        let pagePoint = convert(viewPoint, to: page)

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

        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: false) else {
            if editTextView != nil { commitEditAnimated() }
            super.mouseDown(with: event)
            return
        }

        let pagePoint = convert(viewPoint, to: page)

        // Check if clicking inside the current editor
        if let container = editContainerView {
            let containerPoint = container.superview?.convert(
                convert(viewPoint, from: nil), from: self
            ) ?? .zero
            if container.frame.contains(containerPoint) {
                // Clicking inside editor — let NSTextView handle it
                return
            }
        }

        // Commit previous edit with animation
        if editTextView != nil {
            commitEditAnimated()
        }

        // Dispatch detection to next runloop tick to allow commit animation to start
        DispatchQueue.main.async { [weak self] in
            self?.detectAndOpenEditor(at: pagePoint, on: page)
        }
    }

    private func detectAndOpenEditor(at pagePoint: CGPoint, on page: PDFPage) {
        if let selection = thoroughFindTextBlock(at: pagePoint, on: page) {
            let text = selection.string ?? ""
            let bounds = selection.bounds(for: page)

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            editingPage = page
            editingBounds = bounds
            editingOriginalText = text

            detectFontAttributes(selection: selection, page: page)
            hideHoverHighlight()

            if let doc = document {
                let pageIndex = doc.index(for: page)
                onTextEditRequested?(page, bounds, text, pageIndex)
            }

            showInlineEditor(for: page, bounds: bounds, text: text)
        }
    }

    // MARK: - Scroll/Zoom

    override func layout() {
        super.layout()
        hideHoverHighlight()
        repositionEditor()
    }

    // MARK: - Text Detection

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

    private func thoroughFindTextBlock(at point: CGPoint, on page: PDFPage) -> PDFSelection? {
        if let selection = fastFindTextBlock(at: point, on: page) {
            return selection
        }

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

        let offsets: [(CGFloat, CGFloat)] = [
            (0, 5), (0, -5), (5, 0), (-5, 0),
            (0, 10), (0, -10), (10, 0), (-10, 0),
            (0, 15), (0, -15)
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

    // MARK: - Font Detection (Improved)

    private func detectFontAttributes(selection: PDFSelection, page: PDFPage) {
        guard let attrStr = selection.attributedString, attrStr.length > 0 else {
            let fontSize = estimateFontSize(lineHeight: editingBounds.height)
            detectedFont = NSFont.systemFont(ofSize: fontSize)
            detectedFontColor = .black
            detectedAlignment = .left
            return
        }

        // Sample multiple character positions for more reliable detection
        let samplePositions = [0, min(1, attrStr.length - 1), attrStr.length / 2]
        var bestFont: NSFont?
        var bestColor: NSColor = .black
        var bestAlignment: NSTextAlignment = .left

        for pos in samplePositions where pos < attrStr.length {
            let attrs = attrStr.attributes(at: pos, effectiveRange: nil)

            if let font = attrs[.font] as? NSFont, bestFont == nil {
                let text = selection.string ?? ""
                let lineCount = max(CGFloat(text.components(separatedBy: .newlines).count), 1)
                let expectedLineHeight = editingBounds.height / lineCount
                let maxReasonableSize = expectedLineHeight * 1.3 // Relaxed from 1.1

                if font.pointSize > 0 && font.pointSize <= maxReasonableSize {
                    bestFont = font
                } else {
                    let estimatedSize = estimateFontSize(lineHeight: expectedLineHeight)
                    bestFont = NSFont(name: font.fontName, size: estimatedSize) ??
                               NSFont.systemFont(ofSize: estimatedSize)
                }
            }

            if let color = attrs[.foregroundColor] as? NSColor {
                bestColor = color
            }
            if let para = attrs[.paragraphStyle] as? NSParagraphStyle {
                bestAlignment = para.alignment
            }
        }

        detectedFont = bestFont ?? NSFont.systemFont(ofSize: estimateFontSize(lineHeight: editingBounds.height))
        detectedFontColor = bestColor
        detectedAlignment = bestAlignment
    }

    private func estimateFontSize(lineHeight: CGFloat) -> CGFloat {
        // Improved: use 1.15 divisor (closer to typical PDF leading)
        let estimated = lineHeight / 1.15
        return max(min(estimated, 72), 6)
    }

    private func fontForAnnotation() -> NSFont {
        let size = detectedFont.pointSize
        let fontName = detectedFont.fontName

        if let exactFont = NSFont(name: fontName, size: size) {
            return exactFont
        }

        let familyName = detectedFont.familyName ?? "Helvetica"
        let traits = NSFontManager.shared.traits(of: detectedFont)
        if let familyFont = NSFontManager.shared.font(
            withFamily: familyName, traits: traits,
            weight: NSFontManager.shared.weight(of: detectedFont), size: size
        ) {
            return familyFont
        }

        let fontMap: [String: String] = [
            "TimesNewRoman": "Times-Roman", "Times-Roman": "Times-Roman",
            "ArialMT": "Helvetica", "Arial": "Helvetica",
            "CourierNew": "Courier", "Courier-": "Courier",
            "Calibri": "Helvetica", "Cambria": "Times-Roman",
            "Verdana": "Verdana", "Georgia": "Georgia",
            "Tahoma": "Geneva", "SegoeUI": "Helvetica",
            "Roboto": "Helvetica", "OpenSans": "Helvetica",
            "Lato": "Helvetica", "SourceSansPro": "Helvetica",
            "NotoSans": "Helvetica",
        ]
        for (key, mapped) in fontMap {
            if fontName.contains(key), let f = NSFont(name: mapped, size: size) {
                return f
            }
        }

        return NSFont.systemFont(ofSize: size)
    }

    // MARK: - Hover Highlight (Smooth)

    private func showHoverHighlight(for page: PDFPage, bounds pageBounds: CGRect) {
        if lastHoverPage === page && lastHoverBounds == pageBounds { return }
        lastHoverPage = page
        lastHoverBounds = pageBounds

        hideHoverHighlight()

        let viewRect = convert(pageBounds, from: page)

        let highlight = NSView(frame: viewRect)
        highlight.wantsLayer = true
        highlight.layer?.backgroundColor = hoverHighlightColor.cgColor
        highlight.layer?.borderColor = hoverBorderColor.cgColor
        highlight.layer?.borderWidth = 1
        highlight.layer?.cornerRadius = 2

        // Fade-in animation
        highlight.alphaValue = 0

        if let documentView = documentView {
            let docRect = documentView.convert(viewRect, from: self)
            highlight.frame = docRect
            documentView.addSubview(highlight)
        } else {
            addSubview(highlight)
        }

        hoverHighlight = highlight

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            highlight.animator().alphaValue = 1
        }
    }

    private func hideHoverHighlight() {
        guard let highlight = hoverHighlight else { return }
        // Quick fade-out
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.08
            highlight.animator().alphaValue = 0
        }, completionHandler: {
            highlight.removeFromSuperview()
        })
        hoverHighlight = nil
        lastHoverPage = nil
        lastHoverBounds = .zero
    }

    // MARK: - Inline Editor (Sejda-style)

    private func showInlineEditor(for page: PDFPage, bounds pageBounds: CGRect, text: String) {
        editTextView?.removeFromSuperview()
        editContainerView?.removeFromSuperview()

        let viewRect = convert(pageBounds, from: page)
        let padding: CGFloat = 3
        let editorRect = viewRect.insetBy(dx: -padding - 1, dy: -padding - 1)

        // Scale font for view
        let viewFontSize = max(detectedFont.pointSize * scaleFactor, 8)
        let viewFont: NSFont
        if let scaled = NSFont(name: detectedFont.fontName, size: viewFontSize) {
            viewFont = scaled
        } else {
            viewFont = NSFont.systemFont(ofSize: viewFontSize)
        }

        // Container with Sejda-style border
        let container = NSView(frame: editorRect)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.cgColor
        container.layer?.borderColor = editorBorderColor.cgColor
        container.layer?.borderWidth = 2
        container.layer?.cornerRadius = 3
        container.layer?.shadowColor = editorShadowColor.cgColor
        container.layer?.shadowOpacity = 1
        container.layer?.shadowRadius = 6
        container.layer?.shadowOffset = CGSize(width: 0, height: -1)

        // NSTextView
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

        // Smooth insertion caret color
        textView.insertionPointColor = editorBorderColor.withAlphaComponent(1.0) as NSColor

        container.addSubview(textView)

        // Start transparent for fade-in
        container.alphaValue = 0

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

        // Animate fade-in
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            container.animator().alphaValue = 1
        }, completionHandler: {
            textView.window?.makeFirstResponder(textView)
            textView.selectAll(nil)
        })
    }

    /// Reposition editor on zoom/scroll
    private func repositionEditor() {
        guard let page = editingPage, let container = editContainerView, let textView = editTextView else { return }
        let viewRect = convert(editingBounds, from: page)
        let padding: CGFloat = 3
        let editorRect = viewRect.insetBy(dx: -padding - 1, dy: -padding - 1)

        if let documentView = documentView {
            let docRect = documentView.convert(editorRect, from: self)
            container.frame = docRect
            textView.frame = NSRect(
                x: padding, y: padding,
                width: docRect.width - padding * 2,
                height: docRect.height - padding * 2
            )

            // Rescale font on zoom
            let viewFontSize = max(detectedFont.pointSize * scaleFactor, 8)
            if let scaled = NSFont(name: detectedFont.fontName, size: viewFontSize) {
                textView.font = scaled
            } else {
                textView.font = NSFont.systemFont(ofSize: viewFontSize)
            }
        }
    }

    // MARK: - Commit / Cancel (Animated)

    func commitEdit() {
        commitEditInternal()
    }

    /// Animated commit: fade-out editor, then apply annotation
    private func commitEditAnimated() {
        guard let container = editContainerView else {
            commitEditInternal()
            return
        }

        // Capture values before cleanup
        let textView = editTextView
        let newText = textView?.string ?? ""
        let page = editingPage
        let bounds = editingBounds
        let originalText = editingOriginalText
        let font = fontForAnnotation()
        let fontColor = detectedFontColor
        let alignment = detectedAlignment

        // Fade-out animation
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            container.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Apply annotation after fade completes
            if let page = page, newText != originalText && !newText.isEmpty {
                self?.applyTextAnnotation(to: page, bounds: bounds, text: newText, font: font, fontColor: fontColor, alignment: alignment)
            }
            self?.cleanupEditor()
        })

        // Clear references so we don't double-commit
        editTextView = nil
        editContainerView = nil
        editingPage = nil
    }

    private func commitEditInternal() {
        guard let textView = editTextView, let page = editingPage else {
            cleanupEditor()
            return
        }

        let newText = textView.string
        let bounds = editingBounds

        if newText != editingOriginalText && !newText.isEmpty {
            let annotFont = fontForAnnotation()
            applyTextAnnotation(to: page, bounds: bounds, text: newText, font: annotFont, fontColor: detectedFontColor, alignment: detectedAlignment)
        }

        cleanupEditor()
    }

    private func applyTextAnnotation(to page: PDFPage, bounds: CGRect, text: String, font: NSFont, fontColor: NSColor, alignment: NSTextAlignment) {
        // Cover original text
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

        // FreeText annotation
        let freeTextInset: CGFloat = 2.0
        let textBounds = CGRect(
            x: bounds.origin.x - freeTextInset,
            y: bounds.origin.y - freeTextInset,
            width: bounds.width + freeTextInset * 2,
            height: bounds.height + freeTextInset * 2
        )

        let textAnnotation = PDFAnnotation(bounds: textBounds, forType: .freeText, withProperties: nil)
        textAnnotation.contents = text
        textAnnotation.font = font
        textAnnotation.fontColor = fontColor
        textAnnotation.color = .clear
        textAnnotation.alignment = alignment
        let textBorder = PDFBorder()
        textBorder.lineWidth = 0
        textAnnotation.border = textBorder
        page.addAnnotation(textAnnotation)

        NotificationCenter.default.post(name: .init("AcroromiEditCommitted"), object: nil)
    }

    func cancelEdit() {
        guard let container = editContainerView else {
            cleanupEditor()
            return
        }

        // Fade-out on cancel too
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            container.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.cleanupEditor()
        })
    }

    private func cleanupEditor() {
        editTextView?.removeFromSuperview()
        editTextView = nil
        editContainerView?.removeFromSuperview()
        editContainerView = nil
        editingPage = nil
        editingBounds = .zero
        editingOriginalText = ""
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
                return false // Shift+Enter = newline
            }
            commitEditAnimated()
            return true
        }
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            commitEditAnimated()
            return true
        }
        return false
    }

    // Auto-resize editor as user types
    func textDidChange(_ notification: Notification) {
        guard let textView = editTextView, let container = editContainerView else { return }
        let padding: CGFloat = 3

        // Calculate needed height
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
        let neededHeight = usedRect.height + padding * 2 + 4

        // Only grow, don't shrink below original
        let minHeight = container.frame.height
        if neededHeight > minHeight {
            var newFrame = container.frame
            // Expand downward (PDF coordinate: expand upward in view)
            newFrame.size.height = neededHeight
            newFrame.origin.y = container.frame.maxY - neededHeight

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.08
                container.animator().frame = newFrame
            }

            textView.frame = NSRect(
                x: padding, y: padding,
                width: newFrame.width - padding * 2,
                height: neededHeight - padding * 2
            )
        }
    }
}
