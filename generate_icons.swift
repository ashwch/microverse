#!/usr/bin/swift

import AppKit

// Generate Microverse app icon
func generateIcon(size: CGSize = CGSize(width: 1024, height: 1024)) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    
    // Create gradient background (dark space theme)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0),
        NSColor(red: 0.15, green: 0.05, blue: 0.25, alpha: 1.0)
    ])
    gradient?.draw(in: NSRect(origin: .zero, size: size), angle: -45)
    
    // Draw battery outline with glow effect
    let batteryRect = NSRect(x: size.width * 0.2, y: size.height * 0.35, 
                            width: size.width * 0.5, height: size.height * 0.3)
    
    // Glow effect
    let glowPath = NSBezierPath(roundedRect: batteryRect.insetBy(dx: -10, dy: -10), 
                                xRadius: 30, yRadius: 30)
    let glowGradient = NSGradient(colors: [
        NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.3),
        NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.0)
    ])
    glowGradient?.draw(in: glowPath, relativeCenterPosition: .zero)
    
    // Battery body
    let batteryPath = NSBezierPath(roundedRect: batteryRect, xRadius: 20, yRadius: 20)
    NSColor.white.withAlphaComponent(0.95).setStroke()
    batteryPath.lineWidth = size.width * 0.015
    batteryPath.stroke()
    
    // Battery terminal
    let terminalRect = NSRect(x: size.width * 0.7, y: size.height * 0.45,
                             width: size.width * 0.06, height: size.height * 0.1)
    let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: 8, yRadius: 8)
    NSColor.white.withAlphaComponent(0.95).setFill()
    terminalPath.fill()
    
    // Fill battery with cosmic gradient
    let fillRect = batteryRect.insetBy(dx: size.width * 0.02, dy: size.height * 0.02)
    let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 15, yRadius: 15)
    
    // Save graphics state for clipping
    NSGraphicsContext.current?.saveGraphicsState()
    fillPath.setClip()
    
    // Cosmic gradient fill
    let cosmicGradient = NSGradient(colors: [
        NSColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 1.0),
        NSColor(red: 0.3, green: 0.2, blue: 0.8, alpha: 1.0),
        NSColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 1.0)
    ])
    cosmicGradient?.draw(in: fillRect, angle: 45)
    
    // Add nebula effect
    for _ in 0..<5 {
        let x = fillRect.minX + CGFloat.random(in: 0...fillRect.width)
        let y = fillRect.minY + CGFloat.random(in: 0...fillRect.height)
        let nebula = NSBezierPath(ovalIn: NSRect(x: x - 40, y: y - 40, width: 80, height: 80))
        NSColor(red: 0.8, green: 0.4, blue: 0.9, alpha: 0.2).setFill()
        nebula.fill()
    }
    
    // Add stars
    for _ in 0..<50 {
        let x = fillRect.minX + CGFloat.random(in: 0...fillRect.width)
        let y = fillRect.minY + CGFloat.random(in: 0...fillRect.height)
        let starSize = CGFloat.random(in: 1...4)
        
        let star = NSBezierPath(ovalIn: NSRect(x: x - starSize/2, y: y - starSize/2, 
                                              width: starSize, height: starSize))
        NSColor.white.withAlphaComponent(CGFloat.random(in: 0.5...1.0)).setFill()
        star.fill()
    }
    
    NSGraphicsContext.current?.restoreGraphicsState()
    
    // Add energy bolt
    let boltPath = NSBezierPath()
    let centerX = size.width * 0.45
    let centerY = size.height * 0.5
    let scale = size.width * 0.001
    
    boltPath.move(to: NSPoint(x: centerX - 30 * scale, y: centerY + 60 * scale))
    boltPath.line(to: NSPoint(x: centerX + 10 * scale, y: centerY + 10 * scale))
    boltPath.line(to: NSPoint(x: centerX - 10 * scale, y: centerY + 10 * scale))
    boltPath.line(to: NSPoint(x: centerX + 30 * scale, y: centerY - 60 * scale))
    boltPath.line(to: NSPoint(x: centerX - 10 * scale, y: centerY - 10 * scale))
    boltPath.line(to: NSPoint(x: centerX + 10 * scale, y: centerY - 10 * scale))
    boltPath.close()
    
    // Bolt glow
    NSGraphicsContext.current?.saveGraphicsState()
    boltPath.lineWidth = 10
    NSColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 0.5).setStroke()
    boltPath.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
    
    // Bolt fill
    NSColor.white.setFill()
    boltPath.fill()
    
    image.unlockFocus()
    return image
}

// Save icon sizes
let sizes = [
    (16, "16x16"),
    (32, "16x16@2x"),
    (32, "32x32"),
    (64, "32x32@2x"),
    (128, "128x128"),
    (256, "128x128@2x"),
    (256, "256x256"),
    (512, "256x256@2x"),
    (512, "512x512"),
    (1024, "512x512@2x")
]

// Create iconset directory
let iconsetPath = "AppIcon.iconset"
try FileManager.default.createDirectory(atPath: iconsetPath, 
                                       withIntermediateDirectories: true, 
                                       attributes: nil)

// Generate each size
for (size, name) in sizes {
    let icon = generateIcon(size: CGSize(width: size, height: size))
    if let tiffData = icon.tiffRepresentation,
       let bitmapRep = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
        let filename = "icon_\(name).png"
        try pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
        print("Generated \(filename)")
    }
}

print("\nIcon set created in \(iconsetPath)")
print("To create .icns file, run: iconutil -c icns \(iconsetPath)")