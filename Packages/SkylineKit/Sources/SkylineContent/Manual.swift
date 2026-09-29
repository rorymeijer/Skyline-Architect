import Foundation

/// The player's manual (F3): chapters written in a small Markdown subset, shown in the game
/// and published on the website from the same files (`Resources/Manual`, see MANUAL.md).
///
/// Supported: `#`–`###` headings, paragraphs, `-` bullets, `1.` numbered lists, `>` notes and
/// `|` tables. Inline text keeps its Markdown (`**bold**`, `*italic*`, `` `key` ``, links);
/// a link to `other-chapter.md` points at another chapter.
public struct ManualDocument: Sendable {
    public var chapters: [ManualChapter]

    public init(chapters: [ManualChapter]) {
        self.chapters = chapters
    }

    public func chapter(_ id: String) -> ManualChapter? { chapters.first { $0.id == id } }

    /// Chapters mentioning every word of `query` (case- and diacritic-insensitive), with the
    /// first matching block as a snippet; chapter order.
    public func search(_ query: String) -> [(chapter: ManualChapter, snippet: String)] {
        let words = query.split(whereSeparator: \.isWhitespace).map { String($0) }
        guard !words.isEmpty else { return [] }
        func has(_ text: String, _ word: String) -> Bool {
            text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        return chapters.compactMap { chapter in
            let texts = [chapter.title] + chapter.blocks.map(\.plainText)
            guard words.allSatisfy({ w in texts.contains { has($0, w) } }) else { return nil }
            let snippet = texts.dropFirst().first { t in words.contains { has(t, $0) } } ?? chapter.title
            return (chapter, snippet)
        }
    }
}

public struct ManualChapter: Sendable, Identifiable, Hashable {
    /// File name without the order prefix and extension (`03-transport.md` → `transport`).
    public var id: String
    /// The `#` heading.
    public var title: String
    public var blocks: [ManualBlock]
}

public enum ManualBlock: Sendable, Hashable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case note(String)
    case table(header: [String], rows: [[String]])

    /// Text without Markdown marks, for search.
    public var plainText: String {
        let raw: String
        switch self {
        case let .heading(_, t), let .paragraph(t), let .note(t): raw = t
        case let .bullets(items), let .numbered(items): raw = items.joined(separator: " ")
        case let .table(header, rows): raw = (header + rows.flatMap { $0 }).joined(separator: " ")
        }
        return ManualMarkdown.strip(raw)
    }
}

public enum ManualMarkdown {
    /// Parses one chapter file. The first `#` heading is the title; nil without one.
    public static func chapter(id: String, markdown: String) -> ManualChapter? {
        var title: String?
        var blocks: [ManualBlock] = []
        var paragraph: [String] = []
        var list: (numbered: Bool, items: [String])?
        var note: [String] = []
        var table: [[String]] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
            if let l = list { blocks.append(l.numbered ? .numbered(l.items) : .bullets(l.items)); list = nil }
            if !note.isEmpty { blocks.append(.note(note.joined(separator: " "))); note = [] }
            if !table.isEmpty {
                let rows = table.filter { !$0.allSatisfy { $0.allSatisfy { "-: ".contains($0) } } }   // drop the |---| rule
                blocks.append(.table(header: rows.first ?? [], rows: Array(rows.dropFirst())))
                table = []
            }
        }

        for raw in markdown.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if let (level, text) = heading(line) {
                flush()
                if level == 1 && title == nil { title = text } else { blocks.append(.heading(level: level, text: text)) }
            } else if line.hasPrefix("|") {
                if table.isEmpty { flush() }
                table.append(line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                    .components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) })
            } else if line.hasPrefix(">") {
                if note.isEmpty { flush() }
                note.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
            } else if let item = bullet(line) {
                if list?.numbered != false { flush(); list = (false, []) }
                list?.items.append(item)
            } else if let item = numberedItem(line) {
                if list?.numbered != true { flush(); list = (true, []) }
                list?.items.append(item)
            } else if raw.hasPrefix("  "), var l = list, !l.items.isEmpty {
                l.items[l.items.count - 1] += " " + line                          // continued list item
                list = l
            } else {
                if list != nil || !note.isEmpty || !table.isEmpty { flush() }
                paragraph.append(line)
            }
        }
        flush()
        guard let title else { return nil }
        return ManualChapter(id: id, title: title, blocks: blocks)
    }

    static func heading(_ line: String) -> (Int, String)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...3).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return (hashes, String(line.dropFirst(hashes + 1)))
    }

    static func bullet(_ line: String) -> String? {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") else { return nil }
        return String(line.dropFirst(2))
    }

    static func numberedItem(_ line: String) -> String? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, line.dropFirst(digits.count).hasPrefix(". ") else { return nil }
        return String(line.dropFirst(digits.count + 2))
    }

    /// Inline Markdown removed: `**a**` → a, `[text](x)` → text, backticks dropped.
    public static func strip(_ text: String) -> String {
        var s = text
        while let open = s.range(of: "["), let mid = s.range(of: "](", range: open.upperBound..<s.endIndex),
              let close = s.range(of: ")", range: mid.upperBound..<s.endIndex) {
            s.replaceSubrange(open.lowerBound..<close.upperBound, with: s[open.upperBound..<mid.lowerBound])
        }
        for mark in ["**", "`", "*", "_"] { s = s.replacingOccurrences(of: mark, with: "") }
        return s
    }

    /// Chapter links in a text (`[..](transport.md)` → `transport`), in order.
    public static func chapterLinks(in text: String) -> [String] {
        var out: [String] = []
        var rest = Substring(text)
        while let mid = rest.range(of: "]("), let close = rest.range(of: ")", range: mid.upperBound..<rest.endIndex) {
            let target = rest[mid.upperBound..<close.lowerBound]
            if target.hasSuffix(".md"), !target.contains("/") { out.append(String(target.dropLast(3))) }
            rest = rest[close.upperBound...]
        }
        return out
    }
}

/// A tip shown the first time something happens in the game (F3). Which moment triggers it
/// is the app's business (`id`); the text lives here.
public struct ManualHint: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var text: String
    /// Chapter to read more.
    public var chapter: String?
}

/// The manual and hints bundled with the game.
public struct ManualContent: Sendable {
    public var document: ManualDocument
    public var hints: [ManualHint]

    public func hint(_ id: String) -> ManualHint? { hints.first { $0.id == id } }

    /// Loads `*.md` chapters (file-name order; `NN-` prefixes set the order) and `hints.json`.
    public static func load(from folder: URL = ManualContent.folderURL) throws -> ManualContent {
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var chapters: [ManualChapter] = []
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            let id = name.drop { $0.isNumber || $0 == "-" }
            guard let chapter = ManualMarkdown.chapter(id: String(id), markdown: try String(contentsOf: file, encoding: .utf8)) else {
                throw ContentError(pack: "manual", file: file.lastPathComponent, message: "needs a # title")
            }
            chapters.append(chapter)
        }
        let hintsURL = folder.appendingPathComponent("hints.json")
        let hints = FileManager.default.fileExists(atPath: hintsURL.path)
            ? try JSONDecoder().decode([ManualHint].self, from: Data(contentsOf: hintsURL)) : []
        return ManualContent(document: ManualDocument(chapters: chapters), hints: hints)
    }

    /// Broken references: chapter links, hint chapters and duplicate ids (empty if valid).
    public func problems(extraChapterRefs: [String] = []) -> [String] {
        var p: [String] = []
        let ids = document.chapters.map(\.id)
        if Set(ids).count != ids.count { p.append("duplicate chapter ids") }
        if Set(hints.map(\.id)).count != hints.count { p.append("duplicate hint ids") }
        for chapter in document.chapters {
            let texts = chapter.blocks.flatMap { block -> [String] in
                switch block {
                case let .heading(_, t), let .paragraph(t), let .note(t): [t]
                case let .bullets(items), let .numbered(items): items
                case let .table(header, rows): header + rows.flatMap { $0 }
                }
            }
            for link in texts.flatMap(ManualMarkdown.chapterLinks) where !ids.contains(link) {
                p.append("chapter '\(chapter.id)' links to unknown chapter '\(link)'")
            }
        }
        for hint in hints {
            if hint.title.isEmpty || hint.text.isEmpty { p.append("hint '\(hint.id)' needs a title and text") }
            if let c = hint.chapter, !ids.contains(c) { p.append("hint '\(hint.id)' refers to unknown chapter '\(c)'") }
        }
        for ref in extraChapterRefs where !ids.contains(ref) { p.append("unknown chapter '\(ref)'") }
        return p
    }

    public static var folderURL: URL {
        guard let url = Bundle.module.url(forResource: "Manual", withExtension: nil) else {
            fatalError("Manual missing from SkylineContent bundle")
        }
        return url
    }
}
