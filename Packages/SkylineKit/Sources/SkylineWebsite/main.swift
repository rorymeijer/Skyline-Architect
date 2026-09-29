import Foundation
import SkylineContent

// skyline-website (F3): writes the manual pages of the website from the game's manual.
//
//   swift run skyline-website ../../Website        (from Packages/SkylineKit)
//
// Only `<site>/manual/` is written: the contents page and one page per chapter. Stale
// chapter pages are removed. The landing page and the stylesheet are hand-written.

let arguments = CommandLine.arguments.dropFirst()
guard let site = arguments.first else {
    FileHandle.standardError.write(Data("usage: skyline-website <website folder>\n".utf8))
    exit(2)
}
do {
    let manual = try ManualContent.load()
    let problems = manual.problems()
    guard problems.isEmpty else {
        FileHandle.standardError.write(Data(("manual problems:\n" + problems.joined(separator: "\n") + "\n").utf8))
        exit(1)
    }
    let folder = URL(fileURLWithPath: site).appendingPathComponent("manual", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var written: Set<String> = ["index.html"]
    try ManualHTML.contents(manual.document).write(to: folder.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
    for chapter in manual.document.chapters {
        let name = "\(chapter.id).html"
        try ManualHTML.page(chapter, in: manual.document).write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        written.insert(name)
    }
    for file in try FileManager.default.contentsOfDirectory(atPath: folder.path) where file.hasSuffix(".html") && !written.contains(file) {
        try FileManager.default.removeItem(at: folder.appendingPathComponent(file))
    }
    print("wrote \(written.count) pages to \(folder.path)")
} catch {
    FileHandle.standardError.write(Data("skyline-website: \(error)\n".utf8))
    exit(1)
}
