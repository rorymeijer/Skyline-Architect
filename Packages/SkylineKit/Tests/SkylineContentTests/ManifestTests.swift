import Foundation
import Testing
@testable import SkylineContent

@Suite struct ManifestTests {
    @Test func basePackManifestDecodes() throws {
        let data = try Data(contentsOf: BaseContent.packURL.appendingPathComponent("pack.json"))
        let manifest = try JSONDecoder().decode(ContentPackManifest.self, from: data)
        #expect(manifest.id == "base")
        #expect(manifest.formatVersion == ContentPackManifest.supportedFormatVersion)
    }
}
