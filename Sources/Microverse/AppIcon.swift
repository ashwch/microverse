import SwiftUI
import AppKit

// MARK: - App Icon Generator
struct AppIconGenerator {
    static func generateIcon(size: CGSize = CGSize(width: 1024, height: 1024)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Create gradient background
        let gradient = NSGradient(colors: [
            NSColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0),
            NSColor(red: 0.2, green: 0.1, blue: 0.3, alpha: 1.0)
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: -45)
        
        // Draw battery outline
        let batteryRect = NSRect(x: size.width * 0.15, y: size.height * 0.35, 
                                width: size.width * 0.6, height: size.height * 0.3)
        let batteryPath = NSBezierPath(roundedRect: batteryRect, xRadius: 20, yRadius: 20)
        
        NSColor.white.withAlphaComponent(0.9).setStroke()
        batteryPath.lineWidth = size.width * 0.02
        batteryPath.stroke()
        
        // Battery terminal
        let terminalRect = NSRect(x: size.width * 0.75, y: size.height * 0.45,
                                 width: size.width * 0.08, height: size.height * 0.1)
        let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: 10, yRadius: 10)
        NSColor.white.withAlphaComponent(0.9).setFill()
        terminalPath.fill()
        
        // Fill battery with gradient (universe-like)
        let fillRect = NSRect(x: batteryRect.minX + size.width * 0.02, 
                             y: batteryRect.minY + size.height * 0.02,
                             width: batteryRect.width * 0.8 - size.width * 0.04, 
                             height: batteryRect.height - size.height * 0.04)
        
        let fillGradient = NSGradient(colors: [
            NSColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0),
            NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1.0),
            NSColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)
        ])
        
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 10, yRadius: 10)
        fillGradient?.draw(in: fillPath, angle: 0)
        
        // Add stars/particles for universe effect
        for _ in 0..<30 {
            let x = fillRect.minX + CGFloat.random(in: 0...fillRect.width)
            let y = fillRect.minY + CGFloat.random(in: 0...fillRect.height)
            let starSize = CGFloat.random(in: 2...6)
            
            let star = NSBezierPath(ovalIn: NSRect(x: x - starSize/2, y: y - starSize/2, 
                                                  width: starSize, height: starSize))
            NSColor.white.withAlphaComponent(CGFloat.random(in: 0.3...1.0)).setFill()
            star.fill()
        }
        
        // Add lightning bolt for charging
        let boltPath = NSBezierPath()
        let centerX = size.width * 0.5
        let centerY = size.height * 0.5
        
        boltPath.move(to: NSPoint(x: centerX - size.width * 0.05, y: centerY + size.height * 0.1))
        boltPath.line(to: NSPoint(x: centerX - size.width * 0.02, y: centerY))
        boltPath.line(to: NSPoint(x: centerX + size.width * 0.02, y: centerY + size.height * 0.02))
        boltPath.line(to: NSPoint(x: centerX + size.width * 0.05, y: centerY - size.height * 0.1))
        boltPath.line(to: NSPoint(x: centerX + size.width * 0.02, y: centerY - size.height * 0.02))
        boltPath.line(to: NSPoint(x: centerX - size.width * 0.02, y: centerY - size.height * 0.02))
        boltPath.close()
        
        NSColor.white.setFill()
        boltPath.fill()
        
        image.unlockFocus()
        return image
    }
    
    static func saveIconSet() {
        let sizes = [16, 32, 64, 128, 256, 512, 1024]
        let iconsetPath = "/Users/monty/work/diversio/Microverse/AppIcon.iconset"
        
        // Create iconset directory
        try? FileManager.default.createDirectory(atPath: iconsetPath, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
        
        for size in sizes {
            // Generate 1x
            let icon1x = generateIcon(size: CGSize(width: size, height: size))
            if let tiffData = icon1x.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                let filename = "icon_\(size)x\(size).png"
                try? pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
            }
            
            // Generate 2x for sizes up to 512
            if size <= 512 {
                let icon2x = generateIcon(size: CGSize(width: size * 2, height: size * 2))
                if let tiffData = icon2x.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    let filename = "icon_\(size)x\(size)@2x.png"
                    try? pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
                }
            }
        }
        
        print("Icon set saved to: \(iconsetPath)")
        print("Run: iconutil -c icns \(iconsetPath)")
    }
}

