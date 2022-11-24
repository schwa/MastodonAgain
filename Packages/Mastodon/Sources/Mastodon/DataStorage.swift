import Everything
import Foundation
import os

private let logger: Logger? = Logger()

@available(*, deprecated, message: "MESSAGE")
public class DataStorage {
    public var items: [String: Data] = [:]

    public let path = FSPath.applicationSpecificSupportDirectory / "storage.plist"

    public init() {
        try? load()
    }

    public subscript(key: String) -> Data? {
        get {
            let data = items[key]
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
        guard path.exists else {
            return
        }
        let data = try Data(contentsOf: path.url)
        items = try PropertyListDecoder().decode([String: Data].self, from: data)
    }

    public func save() throws {
        do {
            let data = try PropertyListEncoder().encode(items)
            try data.write(to: path.url)
        }
        catch {
            fatal(error: error)
        }
    }
}

public extension DataStorage {
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
