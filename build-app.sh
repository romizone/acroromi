#!/bin/bash
set -e

echo "========================================="
echo "  Building Acroromi PDF Viewer"
echo "========================================="

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Acroromi"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# Step 1: Build with Swift Package Manager
echo ""
echo "[1/4] Compiling Swift project..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

# Find the built binary (exclude dSYM)
BINARY=$(find "$BUILD_DIR" -name "Acroromi" -type f -path "*/release/*" ! -path "*.dSYM*" | head -1)

if [ -z "$BINARY" ]; then
    echo "Error: Could not find compiled binary"
    exit 1
fi

echo "Binary found at: $BINARY"

# Step 2: Create .app bundle
echo ""
echo "[2/4] Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Create a simple app icon (icns) using built-in tools
echo "[2b/4] Generating app icon..."
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# Generate icon using Python (available on all macOS)
python3 -c "
import subprocess, os, sys

iconset_dir = '$ICONSET_DIR'
sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes:
    # Create a simple icon with Core Graphics via sips
    svg_size = size
    filename = f'icon_{size}x{size}.png'
    filepath = os.path.join(iconset_dir, filename)

    # Use sips to create a colored square as base icon
    subprocess.run([
        'python3', '-c', f'''
import Quartz, CoreFoundation

size = {size}
cs = Quartz.CGColorSpaceCreateDeviceRGB()
ctx = Quartz.CGBitmapContextCreate(None, size, size, 8, 0, cs, Quartz.kCGImageAlphaPremultipliedLast)

# Background - rounded rectangle with gradient
Quartz.CGContextSetRGBFillColor(ctx, 0.2, 0.45, 0.85, 1.0)
rect = Quartz.CGRectMake(0, 0, size, size)
radius = size * 0.18
path = Quartz.CGPathCreateWithRoundedRect(rect.insetBy(dx=size*0.02, dy=size*0.02), radius, radius, None)
Quartz.CGContextAddPath(ctx, path)
Quartz.CGContextFillPath(ctx)

# Draw PDF icon shape
margin = size * 0.2
docW = size * 0.45
docH = size * 0.6
docX = (size - docW) / 2
docY = (size - docH) / 2

Quartz.CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.95)
docRect = Quartz.CGRectMake(docX, docY, docW, docH)
docPath = Quartz.CGPathCreateWithRoundedRect(docRect, size*0.02, size*0.02, None)
Quartz.CGContextAddPath(ctx, docPath)
Quartz.CGContextFillPath(ctx)

# Draw "PDF" text
Quartz.CGContextSetRGBFillColor(ctx, 0.2, 0.45, 0.85, 1.0)
fontSize = size * 0.12
font = Quartz.CGFontCreateWithFontName(\"Helvetica-Bold\")
if font:
    Quartz.CGContextSetFont(ctx, font)
    Quartz.CGContextSetFontSize(ctx, fontSize)

# Draw lines to simulate text
lineY = docY + docH * 0.65
for i in range(3):
    lx = docX + docW * 0.15
    ly = lineY - i * (docH * 0.12)
    lw = docW * 0.7 if i < 2 else docW * 0.4
    Quartz.CGContextFillRect(ctx, Quartz.CGRectMake(lx, ly, lw, size*0.02))

# Red badge for \"PDF\"
badgeW = size * 0.25
badgeH = size * 0.12
badgeX = docX + docW - badgeW * 0.5
badgeY = docY + docH * 0.1
Quartz.CGContextSetRGBFillColor(ctx, 0.85, 0.2, 0.2, 1.0)
badgePath = Quartz.CGPathCreateWithRoundedRect(Quartz.CGRectMake(badgeX, badgeY, badgeW, badgeH), size*0.02, size*0.02, None)
Quartz.CGContextAddPath(ctx, badgePath)
Quartz.CGContextFillPath(ctx)

img = Quartz.CGBitmapContextCreateImage(ctx)
url = CoreFoundation.CFURLCreateWithFileSystemPath(None, \"{filepath}\", Quartz.kCFURLPOSIXPathStyle, False)
dest = Quartz.CGImageDestinationCreateWithURL(url, \"public.png\", 1, None)
Quartz.CGImageDestinationAddImage(dest, img, None)
Quartz.CGImageDestinationFinalize(dest)
'''
    ], capture_output=True)

# Rename to proper iconset naming convention
proper_names = {
    16: ['icon_16x16.png'],
    32: ['icon_16x16@2x.png', 'icon_32x32.png'],
    64: ['icon_32x32@2x.png'],
    128: ['icon_128x128.png'],
    256: ['icon_128x128@2x.png', 'icon_256x256.png'],
    512: ['icon_256x256@2x.png', 'icon_512x512.png'],
    1024: ['icon_512x512@2x.png'],
}

for size in sizes:
    src = os.path.join(iconset_dir, f'icon_{size}x{size}.png')
    if os.path.exists(src):
        names = proper_names.get(size, [])
        for i, name in enumerate(names):
            dst = os.path.join(iconset_dir, name)
            if i == 0:
                os.rename(src, dst)
            else:
                import shutil
                shutil.copy2(os.path.join(iconset_dir, names[0]), dst)
" 2>/dev/null || echo "Icon generation skipped (optional)"

# Convert iconset to icns
if [ -d "$ICONSET_DIR" ] && [ "$(ls -A $ICONSET_DIR 2>/dev/null)" ]; then
    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true
    # Update Info.plist to reference icon
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
fi

# Step 3: Verify the app bundle
echo ""
echo "[3/4] Verifying app bundle..."
if [ -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
    echo "App bundle created: $APP_BUNDLE"
    echo "Bundle size: $(du -sh "$APP_BUNDLE" | cut -f1)"
else
    echo "Error: App bundle creation failed"
    exit 1
fi

# Step 4: Create DMG
echo ""
echo "[4/4] Creating DMG..."
rm -f "$DMG_PATH"

# Create a temporary directory for DMG contents
DMG_TEMP="$BUILD_DIR/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create a symbolic link to Applications
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH" 2>&1

# Cleanup
rm -rf "$DMG_TEMP"
rm -rf "$ICONSET_DIR"

echo ""
echo "========================================="
echo "  Build Complete!"
echo "========================================="
echo ""
echo "  App:  $APP_BUNDLE"
echo "  DMG:  $DMG_PATH"
echo ""
echo "  To run the app:"
echo "    open $APP_BUNDLE"
echo ""
echo "  To distribute:"
echo "    Share the DMG file: $DMG_PATH"
echo "========================================="
