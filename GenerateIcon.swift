#!/usr/bin/env swift
import AppKit
import CoreGraphics

func drawPenguinIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // ---- Background: red gradient rounded rect ----
    let radius = s * 0.22
    let bgRect = CGRect(x: s*0.01, y: s*0.01, width: s*0.98, height: s*0.98)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradColors: [CGFloat] = [0.75, 0.15, 0.15, 1.0,  // bottom: deeper red
                                  1.0, 0.3, 0.25, 1.0]    // top: bright red
    if let gradient = CGGradient(colorSpace: colorSpace, colorComponents: gradColors, locations: [0.0, 1.0], count: 2) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: s/2, y: 0), end: CGPoint(x: s/2, y: s), options: [])
    }
    ctx.restoreGState()

    // ---- Penguin Body (dark) ----
    let bodyW = s * 0.52
    let bodyH = s * 0.55
    let bodyX = (s - bodyW) / 2
    let bodyY = s * 0.12

    ctx.setFillColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0)
    ctx.fillEllipse(in: CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH))

    // ---- White Belly ----
    let bellyW = bodyW * 0.68
    let bellyH = bodyH * 0.72
    let bellyX = (s - bellyW) / 2
    let bellyY = bodyY + bodyH * 0.05
    ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
    ctx.fillEllipse(in: CGRect(x: bellyX, y: bellyY, width: bellyW, height: bellyH))

    // ---- "PDF" text on belly ----
    let pdfFontSize = s * 0.11
    let pdfY = bellyY + bellyH * 0.28
    let pdfX = s * 0.37
    let lw = s * 0.022
    ctx.setFillColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1.0)

    // P
    var lx = pdfX
    ctx.fill(CGRect(x: lx, y: pdfY, width: lw, height: pdfFontSize))
    ctx.fill(CGRect(x: lx, y: pdfY + pdfFontSize * 0.5, width: lw * 3.2, height: lw))
    ctx.fill(CGRect(x: lx, y: pdfY + pdfFontSize - lw, width: lw * 3.2, height: lw))
    ctx.fill(CGRect(x: lx + lw * 2.7, y: pdfY + pdfFontSize * 0.5, width: lw, height: pdfFontSize * 0.5))

    // D
    lx = pdfX + s * 0.09
    ctx.fill(CGRect(x: lx, y: pdfY, width: lw, height: pdfFontSize))
    ctx.fill(CGRect(x: lx, y: pdfY, width: lw * 3.2, height: lw))
    ctx.fill(CGRect(x: lx, y: pdfY + pdfFontSize - lw, width: lw * 3.2, height: lw))
    ctx.fill(CGRect(x: lx + lw * 2.7, y: pdfY, width: lw, height: pdfFontSize))

    // F
    lx = pdfX + s * 0.18
    ctx.fill(CGRect(x: lx, y: pdfY, width: lw, height: pdfFontSize))
    ctx.fill(CGRect(x: lx, y: pdfY + pdfFontSize * 0.45, width: lw * 2.8, height: lw))
    ctx.fill(CGRect(x: lx, y: pdfY + pdfFontSize - lw, width: lw * 3.2, height: lw))

    // ---- Wings ----
    let wingW = s * 0.10
    let wingH = s * 0.25
    let wingY = bodyY + bodyH * 0.25

    ctx.setFillColor(red: 0.22, green: 0.22, blue: 0.28, alpha: 1.0)
    // Left wing
    ctx.saveGState()
    ctx.translateBy(x: bodyX - wingW * 0.1, y: wingY + wingH / 2)
    ctx.rotate(by: 0.2)
    ctx.fillEllipse(in: CGRect(x: -wingW/2, y: -wingH/2, width: wingW, height: wingH))
    ctx.restoreGState()

    // Right wing
    ctx.saveGState()
    ctx.translateBy(x: bodyX + bodyW + wingW * 0.1, y: wingY + wingH / 2)
    ctx.rotate(by: -0.2)
    ctx.fillEllipse(in: CGRect(x: -wingW/2, y: -wingH/2, width: wingW, height: wingH))
    ctx.restoreGState()

    // ---- Feet (orange) ----
    let footW = s * 0.10
    let footH = s * 0.04
    let footY = bodyY - footH * 0.5
    ctx.setFillColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0)
    ctx.fillEllipse(in: CGRect(x: s/2 - footW * 1.3, y: footY, width: footW, height: footH))
    ctx.fillEllipse(in: CGRect(x: s/2 + footW * 0.3, y: footY, width: footW, height: footH))

    // ---- Head (round, dark) ----
    let headSize = s * 0.38
    let headX = (s - headSize) / 2
    let headY = bodyY + bodyH * 0.55
    ctx.setFillColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0)
    ctx.fillEllipse(in: CGRect(x: headX, y: headY, width: headSize, height: headSize))

    // ---- White face area ----
    let faceW = headSize * 0.78
    let faceH = headSize * 0.58
    let faceX = (s - faceW) / 2
    let faceY = headY + headSize * 0.06
    ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
    ctx.fillEllipse(in: CGRect(x: faceX, y: faceY, width: faceW, height: faceH))

    // ---- Eyes (cute, big) ----
    let eyeSize = s * 0.06
    let eyeY = headY + headSize * 0.42
    let eyeSpacing = s * 0.075

    // Left eye bg
    ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
    ctx.fillEllipse(in: CGRect(x: s/2 - eyeSpacing - eyeSize, y: eyeY, width: eyeSize * 2, height: eyeSize * 2.2))
    // Left eye sparkle
    ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
    let sparkle = eyeSize * 0.4
    ctx.fillEllipse(in: CGRect(x: s/2 - eyeSpacing + eyeSize * 0.15, y: eyeY + eyeSize * 1.2, width: sparkle, height: sparkle))

    // Right eye bg
    ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
    ctx.fillEllipse(in: CGRect(x: s/2 + eyeSpacing - eyeSize, y: eyeY, width: eyeSize * 2, height: eyeSize * 2.2))
    // Right eye sparkle
    ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
    ctx.fillEllipse(in: CGRect(x: s/2 + eyeSpacing + eyeSize * 0.15, y: eyeY + eyeSize * 1.2, width: sparkle, height: sparkle))

    // ---- Beak (orange) ----
    let beakW = s * 0.08
    let beakH = s * 0.04
    let beakCenterX = s / 2
    let beakY2 = headY + headSize * 0.25
    ctx.setFillColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: beakCenterX - beakW/2, y: beakY2 + beakH))
    ctx.addLine(to: CGPoint(x: beakCenterX + beakW/2, y: beakY2 + beakH))
    ctx.addLine(to: CGPoint(x: beakCenterX, y: beakY2))
    ctx.closePath()
    ctx.fillPath()

    // ---- Blush cheeks ----
    let blushSize = s * 0.05
    let blushY = headY + headSize * 0.2
    ctx.setFillColor(red: 1.0, green: 0.45, blue: 0.45, alpha: 0.35)
    ctx.fillEllipse(in: CGRect(x: s/2 - eyeSpacing - blushSize * 1.8, y: blushY, width: blushSize * 2.2, height: blushSize * 1.3))
    ctx.fillEllipse(in: CGRect(x: s/2 + eyeSpacing - blushSize * 0.4, y: blushY, width: blushSize * 2.2, height: blushSize * 1.3))

    // ---- Red scarf/bow ----
    let scarfY = headY + headSize * 0.0
    let scarfW = s * 0.18
    let scarfH = s * 0.045
    ctx.setFillColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 0.85)
    ctx.fillEllipse(in: CGRect(x: s/2 - scarfW/2, y: scarfY, width: scarfW, height: scarfH))
    // Bow center knot
    let bowSize = s * 0.028
    ctx.setFillColor(red: 0.80, green: 0.1, blue: 0.1, alpha: 1.0)
    ctx.fillEllipse(in: CGRect(x: s/2 - bowSize/2, y: scarfY + scarfH * 0.15, width: bowSize, height: bowSize))

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// Generate all sizes
let iconsetDir = "/Users/rominurismanto/Documents/ClaudeCode/acroromi/.build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizeMap: [(size: Int, names: [String])] = [
    (16,   ["icon_16x16.png"]),
    (32,   ["icon_16x16@2x.png", "icon_32x32.png"]),
    (64,   ["icon_32x32@2x.png"]),
    (128,  ["icon_128x128.png"]),
    (256,  ["icon_128x128@2x.png", "icon_256x256.png"]),
    (512,  ["icon_256x256@2x.png", "icon_512x512.png"]),
    (1024, ["icon_512x512@2x.png"]),
]

for entry in sizeMap {
    let img = drawPenguinIcon(size: entry.size)
    for name in entry.names {
        let path = "\(iconsetDir)/\(name)"
        savePNG(img, to: path)
    }
    print("Generated \(entry.size)x\(entry.size)")
}

print("Done! Icon files at: \(iconsetDir)")
