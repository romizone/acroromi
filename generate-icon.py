#!/usr/bin/env python3
"""Generate a cute red penguin icon for Acroromi PDF app."""
import Quartz
import CoreFoundation
import os
import math

def draw_penguin_icon(size, filepath):
    cs = Quartz.CGColorSpaceCreateDeviceRGB()
    ctx = Quartz.CGBitmapContextCreate(None, size, size, 8, 0, cs, Quartz.kCGImageAlphaPremultipliedLast)

    s = size  # shorthand

    # ---- Background: soft warm gradient rounded rect ----
    # Draw rounded rect background
    rect = Quartz.CGRectMake(0, 0, s, s)
    radius = s * 0.22
    insetRect = Quartz.CGRectInset(rect, s * 0.01, s * 0.01)
    bgPath = Quartz.CGPathCreateWithRoundedRect(insetRect, radius, radius, None)

    # Gradient background (warm red to deeper red)
    Quartz.CGContextSaveGState(ctx)
    Quartz.CGContextAddPath(ctx, bgPath)
    Quartz.CGContextClip(ctx)

    gradColors = [1.0, 0.3, 0.25, 1.0,   # top: bright red
                  0.75, 0.15, 0.15, 1.0]  # bottom: deeper red
    cfColors = CoreFoundation.CFArrayCreate(None, [], 0, None)
    gradient = Quartz.CGGradientCreateWithColorComponents(cs, gradColors, [0.0, 1.0], 2)
    Quartz.CGContextDrawLinearGradient(ctx, gradient,
        Quartz.CGPointMake(s/2, s), Quartz.CGPointMake(s/2, 0), 0)
    Quartz.CGContextRestoreGState(ctx)

    # ---- Penguin Body (dark/charcoal) ----
    bodyW = s * 0.52
    bodyH = s * 0.55
    bodyX = (s - bodyW) / 2
    bodyY = s * 0.12

    # Body oval (dark grey/black)
    Quartz.CGContextSetRGBFillColor(ctx, 0.18, 0.18, 0.22, 1.0)
    bodyRect = Quartz.CGRectMake(bodyX, bodyY, bodyW, bodyH)
    Quartz.CGContextFillEllipseInRect(ctx, bodyRect)

    # ---- White Belly ----
    bellyW = bodyW * 0.68
    bellyH = bodyH * 0.72
    bellyX = (s - bellyW) / 2
    bellyY = bodyY + bodyH * 0.05
    Quartz.CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 0.95)
    bellyRect = Quartz.CGRectMake(bellyX, bellyY, bellyW, bellyH)
    Quartz.CGContextFillEllipseInRect(ctx, bellyRect)

    # ---- PDF text on belly ----
    # Draw "PDF" text centered on belly
    pdfFontSize = s * 0.10
    # Use simple rectangles to spell "PDF"
    pdfY = bellyY + bellyH * 0.3
    pdfX = s * 0.38
    Quartz.CGContextSetRGBFillColor(ctx, 0.85, 0.15, 0.15, 1.0)

    # Letter P
    lx = pdfX
    lw = s * 0.02
    lh = pdfFontSize
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, pdfY, lw, lh))
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, pdfY + lh * 0.5, lw * 3, lw))
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, pdfY + lh - lw, lw * 3, lw))
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx + lw * 2.5, pdfY + lh * 0.5, lw, lh * 0.5))

    # Letter D
    lx = pdfX + s * 0.08
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, pdfY, lw, lh))
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, pdfY, lw * 3, lw))
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, pdfY + lh - lw, lw * 3, lw))
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx + lw * 2.5, pdfY, lw, lh))

    # Letter F
    lx = pdfX + s * 0.16
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, pdfY, lw, lh))
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, pdfY + lh * 0.45, lw * 2.5, lw))
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, pdfY + lh - lw, lw * 3, lw))

    # ---- Head (round, dark) ----
    headSize = s * 0.38
    headX = (s - headSize) / 2
    headY = bodyY + bodyH * 0.55
    Quartz.CGContextSetRGBFillColor(ctx, 0.18, 0.18, 0.22, 1.0)
    headRect = Quartz.CGRectMake(headX, headY, headSize, headSize)
    Quartz.CGContextFillEllipseInRect(ctx, headRect)

    # ---- White face area ----
    faceW = headSize * 0.75
    faceH = headSize * 0.55
    faceX = (s - faceW) / 2
    faceY = headY + headSize * 0.08
    Quartz.CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 0.95)
    faceRect = Quartz.CGRectMake(faceX, faceY, faceW, faceH)
    Quartz.CGContextFillEllipseInRect(ctx, faceRect)

    # ---- Eyes (cute, big) ----
    eyeSize = s * 0.055
    eyeY = headY + headSize * 0.45
    eyeSpacing = s * 0.07

    # Left eye - white
    Quartz.CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 1.0)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 - eyeSpacing - eyeSize, eyeY, eyeSize * 2, eyeSize * 2))
    # Left pupil
    Quartz.CGContextSetRGBFillColor(ctx, 0.1, 0.1, 0.15, 1.0)
    pupilSize = eyeSize * 0.8
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 - eyeSpacing - pupilSize * 0.3, eyeY + eyeSize * 0.4, pupilSize * 1.3, pupilSize * 1.3))
    # Left eye sparkle
    Quartz.CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 0.9)
    sparkleSize = eyeSize * 0.35
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 - eyeSpacing + eyeSize * 0.2, eyeY + eyeSize * 1.0, sparkleSize, sparkleSize))

    # Right eye - white
    Quartz.CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 1.0)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 + eyeSpacing - eyeSize, eyeY, eyeSize * 2, eyeSize * 2))
    # Right pupil
    Quartz.CGContextSetRGBFillColor(ctx, 0.1, 0.1, 0.15, 1.0)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 + eyeSpacing - pupilSize * 0.3, eyeY + eyeSize * 0.4, pupilSize * 1.3, pupilSize * 1.3))
    # Right eye sparkle
    Quartz.CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 0.9)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 + eyeSpacing + eyeSize * 0.2, eyeY + eyeSize * 1.0, sparkleSize, sparkleSize))

    # ---- Beak (orange/yellow, cute triangle) ----
    beakW = s * 0.07
    beakH = s * 0.04
    beakX = s/2
    beakY = headY + headSize * 0.25
    Quartz.CGContextSetRGBFillColor(ctx, 1.0, 0.65, 0.15, 1.0)
    Quartz.CGContextBeginPath(ctx)
    Quartz.CGContextMoveToPoint(ctx, beakX - beakW/2, beakY + beakH)
    Quartz.CGContextAddLineToPoint(ctx, beakX + beakW/2, beakY + beakH)
    Quartz.CGContextAddLineToPoint(ctx, beakX, beakY)
    Quartz.CGContextClosePath(ctx)
    Quartz.CGContextFillPath(ctx)

    # ---- Blush cheeks (cute pink circles) ----
    blushSize = s * 0.045
    blushY = headY + headSize * 0.22
    Quartz.CGContextSetRGBFillColor(ctx, 1.0, 0.5, 0.5, 0.4)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 - eyeSpacing - blushSize * 1.5, blushY, blushSize * 2, blushSize * 1.2))
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 + eyeSpacing - blushSize * 0.5, blushY, blushSize * 2, blushSize * 1.2))

    # ---- Wings (small, cute, slightly raised) ----
    wingW = s * 0.10
    wingH = s * 0.25
    wingY = bodyY + bodyH * 0.25

    # Left wing
    Quartz.CGContextSetRGBFillColor(ctx, 0.22, 0.22, 0.28, 1.0)
    lwx = bodyX - wingW * 0.3
    Quartz.CGContextSaveGState(ctx)
    Quartz.CGContextTranslateCTM(ctx, lwx + wingW/2, wingY + wingH/2)
    Quartz.CGContextRotateCTM(ctx, 0.2)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(-wingW/2, -wingH/2, wingW, wingH))
    Quartz.CGContextRestoreGState(ctx)

    # Right wing
    rwx = bodyX + bodyW - wingW * 0.7
    Quartz.CGContextSaveGState(ctx)
    Quartz.CGContextTranslateCTM(ctx, rwx + wingW/2, wingY + wingH/2)
    Quartz.CGContextRotateCTM(ctx, -0.2)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(-wingW/2, -wingH/2, wingW, wingH))
    Quartz.CGContextRestoreGState(ctx)

    # ---- Feet (orange) ----
    footW = s * 0.09
    footH = s * 0.035
    footY = bodyY - footH * 0.3
    Quartz.CGContextSetRGBFillColor(ctx, 1.0, 0.65, 0.15, 1.0)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 - footW * 1.3, footY, footW, footH))
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 + footW * 0.3, footY, footW, footH))

    # ---- Small red scarf/bow for cuteness ----
    scarfY = headY + headSize * 0.02
    scarfW = s * 0.14
    scarfH = s * 0.04
    Quartz.CGContextSetRGBFillColor(ctx, 0.95, 0.2, 0.2, 0.9)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 - scarfW/2, scarfY, scarfW, scarfH))
    # Bow center
    bowSize = s * 0.025
    Quartz.CGContextSetRGBFillColor(ctx, 0.85, 0.1, 0.1, 1.0)
    Quartz.CGContextFillEllipseInRect(ctx, Quartz.CGRectMake(
        s/2 - bowSize/2, scarfY + scarfH * 0.1, bowSize, bowSize))

    # ---- Save ----
    img = Quartz.CGBitmapContextCreateImage(ctx)
    url = CoreFoundation.CFURLCreateWithFileSystemPath(None, filepath, Quartz.kCFURLPOSIXPathStyle, False)
    dest = Quartz.CGImageDestinationCreateWithURL(url, "public.png", 1, None)
    Quartz.CGImageDestinationAddImage(dest, img, None)
    Quartz.CGImageDestinationFinalize(dest)


# Generate all icon sizes
iconset_dir = "/Users/rominurismanto/Documents/ClaudeCode/acroromi/.build/AppIcon.iconset"
os.makedirs(iconset_dir, exist_ok=True)

sizes = [16, 32, 64, 128, 256, 512, 1024]
for sz in sizes:
    filepath = os.path.join(iconset_dir, f"icon_{sz}x{sz}.png")
    draw_penguin_icon(sz, filepath)
    print(f"Generated {sz}x{sz}")

# Rename to proper iconset naming
import shutil
proper_names = {
    16: ['icon_16x16.png'],
    32: ['icon_16x16@2x.png', 'icon_32x32.png'],
    64: ['icon_32x32@2x.png'],
    128: ['icon_128x128.png'],
    256: ['icon_128x128@2x.png', 'icon_256x256.png'],
    512: ['icon_256x256@2x.png', 'icon_512x512.png'],
    1024: ['icon_512x512@2x.png'],
}

for sz in sizes:
    src = os.path.join(iconset_dir, f"icon_{sz}x{sz}.png")
    if os.path.exists(src):
        names = proper_names.get(sz, [])
        for i, name in enumerate(names):
            dst = os.path.join(iconset_dir, name)
            if i == 0:
                os.rename(src, dst)
            else:
                shutil.copy2(os.path.join(iconset_dir, names[0]), dst)

print("Icon generation complete!")
