import Testing
@testable import SkylinePresentation

@Suite struct ColorTests {
    @Test func hexAndMix() {
        let c = RGBA(hex: 0xFF8000)
        #expect(c.r == 1 && c.b == 0)
        #expect(abs(c.g - 128.0 / 255.0) < 1e-9)
        #expect(RGBA.black.mixed(with: .white, 0.5) == RGBA(0.5, 0.5, 0.5))
    }
}
