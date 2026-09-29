import Foundation
import Testing
@testable import SkylineContent

/// F3: the player's manual, its hints and the website pages made from it.
@Suite struct ManualTests {
    let manual = try! ManualContent.load()

    @Test func chaptersLoadInOrderWithoutBrokenReferences() throws {
        #expect(manual.document.chapters.map(\.id) == ["getting-started", "building", "transport", "tenants", "amenities", "economy",
                                                        "facilities", "progression", "environment", "emergencies", "estate",
                                                        "scenarios", "controls", "mods"])
        #expect(manual.document.chapters.allSatisfy { !$0.title.isEmpty && $0.blocks.count >= 3 })
        // Tutorial steps point at chapters that exist.
        let library = try ContentLibrary.loadBase()
        let refs = library.orderedScenarios.flatMap { ($0.tutorial ?? []).compactMap(\.chapter) }
        #expect(!refs.isEmpty)
        #expect(manual.problems(extraChapterRefs: refs) == [])
    }

    /// Every hint the app can trigger exists (the app's ids, kept here as the contract).
    @Test func hintsCoverTheAppsTriggers() {
        let triggers = ["welcome", "floor-tool", "room-tool", "shaft-tool", "demolish-tool", "first-tenant", "poor-services",
                        "poor-access", "too-expensive", "first-closing", "first-night", "cash-negative", "first-fire",
                        "first-breakdown", "promotion"]
        #expect(Set(manual.hints.map(\.id)) == Set(triggers))
        #expect(manual.hints.allSatisfy { $0.chapter != nil })
    }

    @Test func parserReadsTheSupportedBlocks() throws {
        let md = """
        # Title

        First line
        continues here with **bold**.

        ## Section
        - one
        - two
          wrapped
        1. first
        2. second

        > A note
        > on two lines.

        | A | B |
        |---|---|
        | 1 | [link](other.md) |
        """
        let c = try #require(ManualMarkdown.chapter(id: "x", markdown: md))
        #expect(c.title == "Title")
        #expect(c.blocks == [.paragraph("First line continues here with **bold**."), .heading(level: 2, text: "Section"),
                             .bullets(["one", "two wrapped"]), .numbered(["first", "second"]), .note("A note on two lines."),
                             .table(header: ["A", "B"], rows: [["1", "[link](other.md)"]])])
        #expect(ManualMarkdown.chapter(id: "y", markdown: "no title") == nil)
        #expect(ManualMarkdown.chapterLinks(in: "see [a](transport.md) and [b](https://x.org)") == ["transport"])
        #expect(ManualMarkdown.strip("**Floor** (`F`) and [Money](economy.md)") == "Floor (F) and Money")
    }

    @Test func searchFindsEveryWord() {
        let hits = manual.document.search("sprinklers brigade")
        #expect(hits.map(\.chapter.id).contains("emergencies"))
        #expect(manual.document.search("zzzz-nothing").isEmpty)
        #expect(manual.document.search("   ").isEmpty)
    }

    @Test func htmlEscapesAndLinks() {
        #expect(ManualHTML.inline("a < b & **c** `F` [x](tenants.md) [y](https://e.org)")
                == "a &lt; b &amp; <strong>c</strong> <kbd>F</kbd> <a href=\"tenants.html\">x</a> <a href=\"https://e.org\">y</a>")
        #expect(ManualHTML.anchor("Stairs and elevators!") == "stairs-and-elevators")
    }

    /// The website's manual (Website/manual) is generated from these files; regenerate with
    /// `swift run skyline-website ../../Website` after changing the manual.
    @Test func websiteManualIsUpToDate() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = repo.appendingPathComponent("Website/manual")
        let index = try String(contentsOf: folder.appendingPathComponent("index.html"), encoding: .utf8)
        #expect(index == ManualHTML.contents(manual.document), "Website/manual/index.html is stale: run skyline-website")
        for chapter in manual.document.chapters {
            let page = try String(contentsOf: folder.appendingPathComponent("\(chapter.id).html"), encoding: .utf8)
            #expect(page == ManualHTML.page(chapter, in: manual.document), "Website/manual/\(chapter.id).html is stale: run skyline-website")
        }
    }
}
