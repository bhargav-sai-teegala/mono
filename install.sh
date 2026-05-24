#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# ── 1. Build release binary ──────────────────────────────────────────────────
echo "→ Building Mono…"
swift build -c release 2>&1 | grep -E "Build complete|error:"

# ── 2. App bundle skeleton ───────────────────────────────────────────────────
APP="$HOME/Applications/Mono.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/Mono "$APP/Contents/MacOS/Mono"
chmod +x "$APP/Contents/MacOS/Mono"

# ── 3. Generate app icon ─────────────────────────────────────────────────────
echo "→ Generating app icon…"
ICONSET="/tmp/Mono.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"

cat > /tmp/make_mono_icon.swift << 'SWIFTEOF'
import AppKit

func makeIcon(size: Int) -> Data? {
    let s  = CGFloat(size)
    let sw = s < 50 ? max(s * 0.09, 2.0) : s * 0.064   // thicker stroke at small sizes
    let r  = s * 0.36

    let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

        // Background: deep dark radial gradient
        let bgC: [CGFloat] = [0.09, 0.04, 0.20, 1.0,  0.02, 0.01, 0.04, 1.0]
        let bgL: [CGFloat] = [0, 1]
        if let g = CGGradient(colorSpace: CGColorSpaceCreateDeviceRGB(),
                               colorComponents: bgC, locations: bgL, count: 2) {
            ctx.drawRadialGradient(g,
                startCenter: CGPoint(x: s*0.5, y: s*0.56), startRadius: 0,
                endCenter:   CGPoint(x: s*0.5, y: s*0.5),  endRadius: s*0.76,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        let cx = s/2, cy = s/2
        // Hexagon path (pointy-top)
        let hex = CGMutablePath()
        for i in 0..<6 {
            let a  = CGFloat(i) * .pi/3 - .pi/6
            let pt = CGPoint(x: cx + r*cos(a), y: cy + r*sin(a))
            if i == 0 { hex.move(to: pt) } else { hex.addLine(to: pt) }
        }
        hex.closeSubpath()

        // Subtle inner glow/fill
        ctx.saveGState()
        ctx.addPath(hex)
        ctx.clip()
        let fillAlpha: CGFloat = s < 50 ? 0.55 : 0.38
        let fC: [CGFloat] = [0.28, 0.10, 0.55, fillAlpha,  0.06, 0.03, 0.12, 0.0]
        let fL: [CGFloat] = [0, 1]
        if let g = CGGradient(colorSpace: CGColorSpaceCreateDeviceRGB(),
                               colorComponents: fC, locations: fL, count: 2) {
            ctx.drawRadialGradient(g,
                startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                endCenter:   CGPoint(x: cx, y: cy), endRadius: r * 1.1,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.restoreGState()

        // Gradient stroke — violet → purple → pink → red-orange → gold
        let strokePath = hex.copy(strokingWithWidth: sw, lineCap: .round,
                                   lineJoin: .round, miterLimit: 4)
        ctx.saveGState()
        ctx.addPath(strokePath)
        ctx.clip()
        let sC: [CGFloat] = [
            0.49, 0.23, 0.93, 1.0,
            0.72, 0.26, 0.97, 1.0,
            0.95, 0.25, 0.58, 1.0,
            0.98, 0.44, 0.15, 1.0,
            0.99, 0.76, 0.09, 1.0,
        ]
        let sL: [CGFloat] = [0, 0.25, 0.5, 0.75, 1.0]
        if let g = CGGradient(colorSpace: CGColorSpaceCreateDeviceRGB(),
                               colorComponents: sC, locations: sL, count: 5) {
            ctx.drawLinearGradient(g,
                start: CGPoint(x: 0, y: s),
                end:   CGPoint(x: s, y: 0),
                options: [])
        }
        ctx.restoreGState()

        return true
    }

    guard let tiff = img.tiffRepresentation,
          let bmp  = NSBitmapImageRep(data: tiff) else { return nil }
    return bmp.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
}

let outDir = CommandLine.arguments[1]
let specs: [(Int, String)] = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]
for (size, name) in specs {
    if let data = makeIcon(size: size) {
        try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    }
}
SWIFTEOF

swift /tmp/make_mono_icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" /tmp/make_mono_icon.swift
echo "✓ App icon created"

# ── 4. Info.plist ────────────────────────────────────────────────────────────
cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>       <string>Mono</string>
    <key>CFBundleIdentifier</key>       <string>com.bhargav.mono</string>
    <key>CFBundleName</key>             <string>Mono</string>
    <key>CFBundleDisplayName</key>      <string>Mono</string>
    <key>CFBundleIconFile</key>         <string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>          <string>1</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <key>LSUIElement</key>              <true/>
    <key>NSPrincipalClass</key>         <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>  <true/>
</dict>
</plist>
PLIST

# ── 5. Launch ────────────────────────────────────────────────────────────────
pkill -x Mono 2>/dev/null || true
sleep 0.4
open "$APP"

echo "✓ Installed → ~/Applications/Mono.app"
echo "✓ Mono is running"
echo ""
echo "  Right-click the menubar icon → Launch at Login"
