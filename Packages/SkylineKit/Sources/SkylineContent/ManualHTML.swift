import Foundation

/// The manual as HTML for the website (F3): one page per chapter, from the same parsed
/// chapters the game shows. Pure string work; `skyline-website` writes the files.
public enum ManualHTML {
    /// A chapter's body (no page chrome). Chapter links become `id.html`.
    public static func body(_ chapter: ManualChapter) -> String {
        var out = "<h1>\(inline(chapter.title))</h1>\n"
        for block in chapter.blocks {
            switch block {
            case let .heading(level, text):
                let tag = "h\(min(level, 3))"
                out += "<\(tag) id=\"\(anchor(text))\">\(inline(text))</\(tag)>\n"
            case let .paragraph(text):
                out += "<p>\(inline(text))</p>\n"
            case let .bullets(items):
                out += "<ul>\n" + items.map { "  <li>\(inline($0))</li>\n" }.joined() + "</ul>\n"
            case let .numbered(items):
                out += "<ol>\n" + items.map { "  <li>\(inline($0))</li>\n" }.joined() + "</ol>\n"
            case let .note(text):
                out += "<aside class=\"note\">\(inline(text))</aside>\n"
            case let .table(header, rows):
                out += "<table>\n  <thead><tr>" + header.map { "<th>\(inline($0))</th>" }.joined() + "</tr></thead>\n  <tbody>\n"
                for row in rows { out += "    <tr>" + row.map { "<td>\(inline($0))</td>" }.joined() + "</tr>\n" }
                out += "  </tbody>\n</table>\n"
            }
        }
        return out
    }

    /// Inline Markdown to HTML: escapes first, then `code`, **bold**, *italic* and links.
    public static func inline(_ text: String) -> String {
        var s = escape(text)
        s = replace(s, pattern: "`([^`]+)`", with: "<kbd>$1</kbd>")
        s = replace(s, pattern: "\\*\\*([^*]+)\\*\\*", with: "<strong>$1</strong>")
        s = replace(s, pattern: "\\*([^*]+)\\*", with: "<em>$1</em>")
        s = replace(s, pattern: "\\[([^\\]]+)\\]\\(([a-z0-9-]+)\\.md(#[a-z0-9-]+)?\\)", with: "<a href=\"$2.html$3\">$1</a>")
        s = replace(s, pattern: "\\[([^\\]]+)\\]\\((https?://[^)\\s]+)\\)", with: "<a href=\"$2\">$1</a>")
        return s
    }

    public static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// `Stairs and elevators` → `stairs-and-elevators`.
    public static func anchor(_ text: String) -> String {
        let lowered = ManualMarkdown.strip(text).lowercased()
        let kept = lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(kept).split(separator: "-").joined(separator: "-")
    }

    private static func replace(_ s: String, pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return s }
        return regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
}

extension ManualHTML {
    /// A whole chapter page of the website's manual (`Website/manual/<id>.html`).
    public static func page(_ chapter: ManualChapter, in document: ManualDocument) -> String {
        let index = document.chapters.firstIndex { $0.id == chapter.id } ?? 0
        let previous = index > 0 ? document.chapters[index - 1] : nil
        let next = index + 1 < document.chapters.count ? document.chapters[index + 1] : nil
        var nav = "<nav class=\"pager\">"
        if let previous { nav += "<a href=\"\(previous.id).html\">← \(escape(previous.title))</a>" }
        nav += "<a href=\"index.html\">Contents</a>"
        if let next { nav += "<a href=\"\(next.id).html\">\(escape(next.title)) →</a>" }
        nav += "</nav>\n"
        return shell(title: "\(escape(chapter.title)) — Skyline Architect manual", sidebar: sidebar(document, current: chapter.id),
                     main: body(chapter) + nav)
    }

    /// The manual's contents page (`Website/manual/index.html`), with a search box that
    /// filters the chapter list by the words in each chapter.
    public static func contents(_ document: ManualDocument) -> String {
        var main = "<h1>Skyline Architect manual</h1>\n"
        main += "<p>Everything the game does, chapter by chapter. The same text is in the game: open <strong>Help ▸ Skyline Architect Manual</strong> or <strong>Manual</strong> in the main menu.</p>\n"
        main += "<input id=\"search\" type=\"search\" placeholder=\"Search the manual\" aria-label=\"Search the manual\">\n<ol class=\"chapters\">\n"
        for chapter in document.chapters {
            let words = ([chapter.title] + chapter.blocks.map(\.plainText)).joined(separator: " ").lowercased()
            let sections = chapter.blocks.compactMap { block -> String? in
                if case let .heading(2, text) = block { return ManualMarkdown.strip(text) }
                return nil
            }
            main += "  <li data-words=\"\(escape(words))\"><a href=\"\(chapter.id).html\">\(escape(chapter.title))</a>"
            if !sections.isEmpty { main += "<span class=\"sections\">\(escape(sections.joined(separator: " · ")))</span>" }
            main += "</li>\n"
        }
        main += "</ol>\n<p id=\"none\" hidden>No chapter mentions that.</p>\n"
        main += """
        <script>
        const box = document.getElementById('search');
        box.addEventListener('input', () => {
          const words = box.value.toLowerCase().split(/\\s+/).filter(Boolean);
          let shown = 0;
          for (const li of document.querySelectorAll('.chapters li')) {
            const hit = words.every(w => li.dataset.words.includes(w));
            li.hidden = !hit; if (hit) shown++;
          }
          document.getElementById('none').hidden = shown > 0;
        });
        </script>

        """
        return shell(title: "Manual — Skyline Architect", sidebar: sidebar(document, current: nil), main: main)
    }

    static func sidebar(_ document: ManualDocument, current: String?) -> String {
        var s = "<nav class=\"toc\" aria-label=\"Chapters\">\n  <a class=\"home\" href=\"../index.html\">Skyline Architect</a>\n"
        s += "  <a href=\"index.html\"\(current == nil ? " aria-current=\"page\"" : "")>Contents</a>\n"
        for chapter in document.chapters {
            s += "  <a href=\"\(chapter.id).html\"\(chapter.id == current ? " aria-current=\"page\"" : "")>\(escape(chapter.title))</a>\n"
        }
        return s + "</nav>\n"
    }

    static func shell(title: String, sidebar: String, main: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(title)</title>
        <link rel="stylesheet" href="../assets/style.css">
        </head>
        <!-- Generated by skyline-website from Packages/SkylineKit/Sources/SkylineContent/Resources/Manual. Do not edit. -->
        <body class="manual">
        \(sidebar)<main>
        \(main)</main>
        </body>
        </html>

        """
    }
}
