import Everything
import Foundation
import os

private let logger: Logger? = Logger()

public class Storage {
    public static let shared = Storage()

    public var items: [String: Data] = [:]

    public let path = FSPath.applicationSpecificSupportDirectory / "storage.plist"

    public init() {
        try! load()
    }

    public subscript(key: String) -> Data? {
        get {
            let data = items[key]
            logger?.debug("Fetching data for key: \(key), \(data != nil ? "hit" : "miss")")
            return data
        }
        set {
            if newValue == nil {
                items[key] = nil
                logger?.debug("Setting data for key: \(key)")
            }
            else {
                items[key] = newValue
                logger?.debug("Erasing data for key: \(key)")
            }

            try! save()
        }
    }

    public func load() throws {
        logger?.debug("Storage.load")
        guard path.exists else {
            return
        }
        let data = try Data(contentsOf: path.url)
        items = try PropertyListDecoder().decode([String: Data].self, from: data)
    }

    public func save() throws {
        logger?.debug("Storage.save")
        let data = try! PropertyListEncoder().encode(items)
        try data.write(to: path.url)
    }
}

public extension Storage {
    subscript<T>(key: String) -> T? where T: Codable {
        get {
            guard let data = self[key] else {
                return nil
            }
            let value = try! JSONDecoder().decode(T.self, from: data)
            return value
        }
        set {
            if let newValue {
                let data = try! JSONEncoder().encode(newValue)
                self[key] = data
            }
            else {
                self[key] = nil
            }
        }
    }
}

public func funHash(_ value: Int) -> String {
    let adjectives = ["abrupt", "acidic", "adorable", "adventurous", "aggressive", "agitated", "alert", "aloof", "bored", "brave", "bright", "colossal", "condescending", "confused", "cooperative", "corny", "costly", "courageous", "cruel", "despicable", "determined", "dilapidated", "diminutive", "distressed", "disturbed", "dizzy", "exasperated", "excited", "exhilarated", "extensive", "exuberant", "frothy", "frustrating", "funny", "fuzzy", "gaudy", "graceful", "greasy", "grieving", "gritty", "grotesque", "grubby", "grumpy", "handsome", "happy", "hollow", "hungry", "hurt", "icy", "ideal", "immense", "impressionable", "intrigued", "irate", "foolish", "frantic", "fresh", "friendly", "frightened", "frothy", "frustrating", "glorious", "gorgeous", "grubby", "happy", "harebrained", "healthy", "helpful", "helpless", "high", "hollow", "homely", "large", "lazy", "livid", "lonely", "loose", "lovely", "lucky", "mysterious", "narrow", "nasty", "outrageous", "panicky", "perfect", "perplexed", "quizzical", "teeny", "tender", "tense", "terrible", "tricky", "troubled", "unsightly", "upset", "wicked", "yummy", "zany", "zealous", "zippy"]

    var rng = SplitMix64(s: UInt64(bitPattern: Int64(value)))
    return "\(adjectives.randomElement(using: &rng)!)-\(allEmoji.randomElement(using: &rng)!)-\(Int.random(in: 1...1000, using: &rng)))"
}
