import CoreGraphics
import SpriteKit
import SkylineCore
import SkylinePresentation

// Thin conversions between the platform-neutral engine types and Apple graphics types.

extension Vec2 {
    init(_ p: CGPoint) { self.init(Double(p.x), Double(p.y)) }
    init(_ s: CGSize) { self.init(Double(s.width), Double(s.height)) }
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    var cgSize: CGSize { CGSize(width: x, height: y) }
}

extension Rect {
    var cgRect: CGRect { CGRect(x: minX, y: minY, width: width, height: height) }
}

extension RGBA {
    var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var skColor: SKColor { SKColor(red: r, green: g, blue: b, alpha: a) }
}

enum ColorSpaces {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
}
