import Foundation
import SwiftSoup
import SwiftUI

// swiftlint:ignore cyclomatic_complexity

private typealias Element = SwiftSoup.Element

public enum HTMLError: Error {
    case generic(String)
}

public struct HTML: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension HTML: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

extension HTML {
    var text: String {
        get throws {
            try SwiftSoup.parseBodyFragment(rawValue).text()
        }
    }
}

public extension HTML {
    var safeHTML: HTML {
        get throws {
            // swiftlint:disable:next inclusive_language
            let whitelist = try Whitelist.basic()
                .addAttributes("span", "class")
                .addAttributes("a", "class")
            guard let clean = try SwiftSoup.clean(rawValue, whitelist) else {
                throw HTMLError.generic("Failed to clean HTML")
            }
            return HTML(clean)
        }
    }
}

public extension HTML {
    var rewrittenMastodonHTML: HTML {
        get throws {
            let doc: Document = try SwiftSoup.parseBodyFragment(safeHTML.rawValue)
            for user in try doc.select("span.h-card") {
                guard let anchor = try user.select("a[href]").first() else {
                    throw HTMLError.generic("Failed to find an anchor in an h-card span.")
                }
                let url = try anchor.attr("href")
                try user.tagName("a")
                try user.attr("href", url)
                try user.text(user.text())
                try user.removeClass("h-card")
                try user.addClass("user")
            }

            for hashtag in try doc.select("a.hashtag, a.mention") {
                try hashtag.removeAttr("rel")
                try hashtag.removeClass("mention")
                try hashtag.removeAttr("rel")
                try hashtag.addClass("hashtag")
                try hashtag.text(hashtag.text())
            }

            for link in try doc.select("a:not(.user, .hashtag)") {
                try link.text(link.text())
                try link.addClass("link")
            }
            return HTML(try doc.html())
        }
    }

    var safeMastodonAttributedString: AttributedString {
        do {
            return try mastodonAttributedString
        }
        catch {
            print("ERROR PARSING HTML: \(error)")
            print(rawValue)
            // swiftlint:disable:next force_try
            return AttributedString(try! text, attributes: .init([
                .strikethroughStyle: 1,
                .strikethroughColor: Color.red
            ]))
        }
    }

    internal enum Atom: Equatable {
        case linebreak
        case text(String)
        case link(text: String, link: String)
    }

    internal var mastodonAtoms: [Atom] {
        /// Break HTML into links, texts and linebreak. Use rules from https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model/Whitespace to clean up whitespace. (TODO: Not fully implemented).
        get throws {
            let html = try SwiftSoup.parseBodyFragment(rewrittenMastodonHTML.rawValue)
            let root = try html.select("html body").only()
            var atoms: [Atom] = []
            func walk(_ node: Node) throws {
                for child in node.getChildNodes() {
                    switch child {
                    case let text as TextNode:
                        var text = text.text()
                        if atoms.isEmpty || atoms.last == .linebreak {
                            text = String(text.trimmingPrefix { $0.isWhitespace })
                        }
                        if case let .text(string) = atoms.last {
                            atoms.replaceLast(.text(string.appending(text)))
                        }
                        else {
                            if !text.isEmpty {
                                atoms.append(.text(text))
                            }
                        }
                    case let element as Element:
                        let tagName = element.tagName()
                        switch tagName {
                        case "a":
                            let text = try element.text()
                            let link = try element.attr("href")
                            //                        let classnames = try node.classNames()
                            atoms.append(.link(text: text, link: link))
                        case "br":
                            guard !atoms.isEmpty else {
                                continue
                            }
                            atoms.append(.linebreak)
                        case "span":
                            try walk(element)
                        case "p":
                            try walk(element)
                            guard !atoms.isEmpty else {
                                continue
                            }
                            atoms.append(.linebreak)
                        default:
                            throw HTMLError.generic("Unknown tag: \(tagName)")
                        }
                    default:
                        throw HTMLError.generic("Unknown element type \(type(of: child))")
                    }
                }
            }

            try walk(root)

            if atoms.last == .linebreak {
                atoms = atoms.dropLast()
            }

            //            print("########################################################################################")
            //            for atom in atoms {
            //                print(atom)
            //            }
            //            print("########################################################################################")

            return atoms
        }
    }

    var mastodonAttributedString: AttributedString {
        get throws {
            // TODO: this parses twice. We can make more efficient by returning a SwiftSoup document from rewrittenMastodonHTML
            let atoms = try mastodonAtoms
            return atoms.reduce(into: AttributedString()) { partialResult, atom in
                switch atom {
                case .link(text: let text, link: let link):
                    let a = AttributedString(text, attributes: .init([.link: link]))
                    partialResult.append(a)
                case .text(let string):
                    let a = AttributedString(string)
                    partialResult.append(a)
                case .linebreak:
                    let a = AttributedString("\n")
                    partialResult.append(a)
                }
            }
        }
    }
}

internal extension Elements {
    func only() throws -> Element {
        guard size() == 1 else {
            throw HTMLError.generic("Expected only 1 child.")
        }
        return first()!
    }
}

internal extension MutableCollection {
    mutating func replaceLast(_ element: Element) {
        self[self.index(self.endIndex, offsetBy: -1)] = element
    }

    func replacingLast(_ element: Element) -> Self {
        var copy = self
        copy.replaceLast(element)
        return self
    }
}
