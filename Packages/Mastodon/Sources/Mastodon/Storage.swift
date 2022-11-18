import Everything
import Foundation
import os

private let logger: Logger? = Logger()

public class Storage {
    public static let shared = Storage()

    public var items: [String: Data] = [:]

    public let path = FSPath.applicationSpecificSupportDirectory / "storage.plist"

    public init() {
        try? load()
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
            do {
                try save()
            }
            catch {
                fatal(error: error)
            }
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
        do {
            let data = try PropertyListEncoder().encode(items)
            try data.write(to: path.url)
        }
        catch {
            fatal(error: error)
        }
    }
}

public extension Storage {
    subscript<T>(key: String) -> T? where T: Codable {
        get {
            do {
                guard let data = self[key] else {
                    return nil
                }
                let value = try JSONDecoder().decode(T.self, from: data)
                return value
            }
            catch {
                fatal(error: error)
            }
        }
        set {
            do {
                if let newValue {
                    let data = try JSONEncoder().encode(newValue)
                    self[key] = data
                }
                else {
                    self[key] = nil
                }
            }
            catch {
                fatal(error: error)
            }
        }
    }
}
