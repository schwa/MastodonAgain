import AppKit
import Foundation
@_spi(SPI) import Storage

@main
public struct CLI {
    public private(set) var text = "Hello, World!"

    public static func main() throws {
        let storage = Storage()

        storage.register(type: String.self) { value in
            try JSONEncoder().encode(value)
        } decoder: { data in
            try JSONDecoder().decode(String.self, from: data)
        }

        try storage.open(path: "Test.data")
        storage["test_key"] = "hello"

        print(storage.cache.count)

        let hello = storage["test_key", String.self]
        print(hello as Any)
        let hello2: String? = storage["test_key"]
        print(hello2 as Any)

//        print(storage["hello"] as String)
        print("Writing N identical keys")
        for x in 0..<100_000 {
            storage["hello"] = "world \(x)"
        }
        print(try storage.size())
        try storage.compact()
        print(try storage.size())

        let pwd = ProcessInfo.processInfo.environment["PWD"]!
        let url = URL(filePath: pwd)
        NSWorkspace.shared.open(url)

        try storage.compact()
    }
}
