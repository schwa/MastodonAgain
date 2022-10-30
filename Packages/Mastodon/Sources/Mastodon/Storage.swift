import Foundation
import Everything

public class Storage {

    public static let shared = Storage()

    public var items: [String: Data] = [:]

    public let path = FSPath.applicationSpecificSupportDirectory / "storage.plist"

    public init() {
        try! load()
    }

    public subscript(key: String) -> Data? {
        get {
            return items[key]
        }
        set {
            if newValue == nil {
                items[key] = nil
            }
            else {
                items[key] = newValue
            }

            try! save()
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
        let data = try! PropertyListEncoder().encode(items)
        try data.write(to: path.url)
    }
}

public extension Storage {
    subscript <T>(key: String) -> T? where T: Codable {
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
