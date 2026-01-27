#if DEBUG
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Utilities for generating crisp, tightly-cropped screenshots in DEBUG builds.
///
/// Why this exists:
/// - The repo’s website (GitHub Pages) and README are driven by images in `docs/`.
/// - Capturing “perfectly cropped” windows via `screencapture` is often blocked in CI/agent contexts.
/// - Rendering an app window's `contentView` to PNG is deterministic and doesn't require screen-capture privileges.
///
/// What this produces:
/// - A PNG snapshot of an `NSView` (typically a window's content view).
/// - Optional "trim alpha" post-processing for large transparent windows (e.g., notch/glow surfaces).
///
/// AppKit view rendering is main-thread / main-actor bound, so all entry points are `@MainActor`.
@MainActor
enum DebugScreenshotExporter {
  struct TrimAlphaOptions: Sendable, Equatable {
    /// Pixels with alpha ≤ threshold are treated as transparent background.
    var alphaThreshold: UInt8 = 8
    /// Padding (in pixels) added around the detected non-transparent bounds.
    var padding: Int = 18
  }

  static func exportPNG(
    view: NSView,
    to url: URL,
    scale: CGFloat = 2.0,
    trimAlpha: TrimAlphaOptions? = nil,
    backgroundColor: NSColor? = nil
  ) throws {
    let bounds = view.bounds
    guard bounds.width > 1, bounds.height > 1 else {
      throw NSError(
        domain: "com.microverse.app.screenshots",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "View has zero-size bounds: \(bounds)"]
      )
    }

    view.layoutSubtreeIfNeeded()
    view.displayIfNeeded()

    // Render using AppKit's display caching into a bitmap at the requested scale.
    let pixelWidth = Int((bounds.width * scale).rounded(.up))
    let pixelHeight = Int((bounds.height * scale).rounded(.up))

    guard
      let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelWidth,
        pixelsHigh: pixelHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      )
    else {
      throw NSError(
        domain: "com.microverse.app.screenshots",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to allocate NSBitmapImageRep"]
      )
    }

    // Set size in points so the bitmap knows its pixel density.
    rep.size = bounds.size

    view.cacheDisplay(in: bounds, to: rep)

    guard let cgImage = rep.cgImage else {
      throw NSError(
        domain: "com.microverse.app.screenshots",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage from NSBitmapImageRep"]
      )
    }

    let trimmed: CGImage
    if let trimAlpha {
      trimmed = trimmedAlpha(image: cgImage, options: trimAlpha) ?? cgImage
    } else {
      trimmed = cgImage
    }

    let outputImage: CGImage
    if let backgroundColor {
      outputImage = compositedOverBackground(image: trimmed, color: backgroundColor) ?? trimmed
    } else {
      outputImage = trimmed
    }

    try writePNG(image: outputImage, to: url)
  }

  static func exportPNG(
    window: NSWindow,
    to url: URL,
    scale: CGFloat = 2.0,
    trimAlpha: TrimAlphaOptions? = nil,
    backgroundColor: NSColor? = nil
  ) throws {
    guard let view = window.contentView else {
      throw NSError(
        domain: "com.microverse.app.screenshots",
        code: 5,
        userInfo: [NSLocalizedDescriptionKey: "Window has no contentView"]
      )
    }
    try exportPNG(view: view, to: url, scale: scale, trimAlpha: trimAlpha, backgroundColor: backgroundColor)
  }

  private static func trimmedAlpha(image: CGImage, options: TrimAlphaOptions) -> CGImage? {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return nil }

    // Draw into a known pixel format buffer so we can reliably scan alpha.
    let bytesPerRow = width * 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)

    let normalizedImage: CGImage = buffer.withUnsafeMutableBytes { raw in
      let ctx = CGContext(
        data: raw.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
      ctx?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return ctx?.makeImage() ?? image
    }

    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1

    // Scan alpha in the normalized buffer. (Row 0 is the top row for CGImage data provider output.)
    buffer.withUnsafeBytes { raw in
      guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

      for y in 0..<height {
        let rowStart = y * bytesPerRow
        for x in 0..<width {
          let a = base[rowStart + x * 4 + 3]
          if a > options.alphaThreshold {
            if x < minX { minX = x }
            if y < minY { minY = y }
            if x > maxX { maxX = x }
            if y > maxY { maxY = y }
          }
        }
      }
    }

    guard maxX >= 0, maxY >= 0, minX <= maxX, minY <= maxY else {
      return nil
    }

    let pad = max(0, options.padding)
    let cropMinX = max(0, minX - pad)
    let cropMinY = max(0, minY - pad)
    let cropMaxX = min(width - 1, maxX + pad)
    let cropMaxY = min(height - 1, maxY + pad)

    let cropRect = CGRect(
      x: cropMinX,
      y: cropMinY,
      width: cropMaxX - cropMinX + 1,
      height: cropMaxY - cropMinY + 1
    )

    return normalizedImage.cropping(to: cropRect)
  }

  private static func compositedOverBackground(image: CGImage, color: NSColor) -> CGImage? {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return nil }

    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: cs,
      bitmapInfo: info
    ) else {
      return nil
    }

    let cg = (color.usingColorSpace(.deviceRGB) ?? color).cgColor
    ctx.setFillColor(cg)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return ctx.makeImage()
  }

  private static func writePNG(image: CGImage, to url: URL) throws {
    let dir = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
      throw NSError(
        domain: "com.microverse.app.screenshots",
        code: 6,
        userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImageDestination"]
      )
    }

    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
      throw NSError(
        domain: "com.microverse.app.screenshots",
        code: 7,
        userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG write"]
      )
    }
  }
}
#endif
