import Everything
import Foundation
import os

private let logger: Logger? = Logger()

public enum StorageError: Error {
    case unknown
}

public class Storage {
    internal struct Record {
        enum Value {
            case encoded(Data)
            case raw(Any)
        }
        let value: Value
    }

    private var cache: [String: Record] = [:]
    private var log: StorageLog
    private var encoder = JSONEncoder()
    private var decoder = JSONDecoder()

    public init(path: String) throws {
        if FileManager().fileExists(atPath: path) {
            cache = Dictionary(uniqueKeysWithValues: try StorageLog.read(path: path).map { key, data in
                (key, Record(value: .encoded(data)))
            })
        }

        log = try StorageLog(path: path)
    }

    deinit {
//        cache.map { (key, record) in
//            switch record.value {
//            case .encoded(let data):
//                return (key, data)
//            case .raw(let value):
//                fatalError()
//            }
//        }

    }

    public subscript <T>(key: String, type: T.Type) -> T? where T: Codable {
        get {
            do {
                guard let record = cache[key] else {
                    return nil
                }
                switch record.value {
                case .raw(let value):
                    return value as? T
                case .encoded(let data):
                    let value = try decoder.decode(T.self, from: data)
                    self[key, type] = value
                    return value
                }
            }
            catch {
                fatal(error: error)
            }
        }
        set {
            do {
                if let newValue {
                    cache[key] = Record(value: .raw(newValue))
                    let data = try encoder.encode(newValue)
                    log.post(event: { .set(key, data) })
                }
                else {
                    cache[key] = nil
                    log.post(event: { .delete(key) })
                }
            }
            catch {
                fatal(error: error)
            }
        }
    }
}

internal class StorageLog {
    enum Event: Codable {
        case session(UUID, Date)
        case set(String, Data)
        case delete(String)
        case snapshot([String: Data])
    }

    let fd: Int32
    let encoder = JSONEncoder()

    let queue = DispatchQueue(label: "StorageLog", qos: .default, attributes: [], autoreleaseFrequency: .never, target: nil)
    let group = DispatchGroup()

    static func read(path: String) throws -> [String: Data] {
        let decoder = JSONDecoder()
        var cache: [String: Data] = [:]
        let data = try Data(contentsOf: URL(filePath: path))
        try data.withUnsafeBytes { buffer in
            var offset = buffer.startIndex
            while offset < buffer.endIndex {
                let count = buffer.loadUnaligned(fromByteOffset: offset, as: Int.self)
                offset = buffer.index(offset, offsetBy: MemoryLayout.size(ofValue: count))

                let remaining = buffer.endIndex - offset
                guard remaining >= count else {
                    fatalError("Log file corrupt?")
                }
                let data = Data(bytes: buffer.baseAddress! + offset, count: count)
                let event = try decoder.decode(StorageLog.Event.self, from: data)
                offset = buffer.index(offset, offsetBy: count)
                switch event {
                case .set(let key, let data):
                    cache[key] = data
                case .delete(let key):
                    cache[key] = nil
                case .session(let uuid, let date):
                    logger?.info("Session: \(uuid) \(date)")
                case .snapshot(let snapshot):
                    cache = snapshot
                }
            }
        }
        return cache
    }

    init(path: String) throws {
        let fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0o755)
        if fd < 0 {
            throw StorageError.unknown
        }
        self.fd = fd
        post {
            .session(UUID(), .now)
        }
    }

    deinit {
        logger?.debug("deinit start")
        group.wait()
//        fsync(fd)
        let result = fcntl(fd, F_FULLFSYNC)
        logger?.debug("FULLFSYNC: \(result)")
        close(fd)
        logger?.debug("deinit end")
    }

    func post(event: @escaping () -> Event) {
        queue.async(group: group) { [encoder, fd] in
            autoreleasepool {
                do {
                    let data = try encoder.encode(event())
                    try withUnsafeBytes(of: data.count) { count in
                        let result = data.withUnsafeBytes { data in
                            let vector = [
                                iovec(iov_base: count.baseAddress, iov_len: count.count),
                                iovec(iov_base: data.baseAddress, iov_len: data.count)
                            ]
                            return vector.withUnsafeBufferPointer { vectorPointer in
                                writev(fd, vectorPointer.baseAddress, Int32(vector.count))
                            }
                        }
                        guard result >= count.count else {
                            throw StorageError.unknown
                        }
                    }
                }
                catch {
                    fatal(error: error)
                }
            }
        }
    }
}

extension iovec {
    init(iov_base: UnsafeRawPointer!, iov_len: Int) {
        self = iovec(iov_base: UnsafeMutableRawPointer(mutating: iov_base), iov_len: iov_len)
    }
}
//
//print(ProcessInfo.processInfo.environment["PWD"])
//
//do {
//    print("Loading")
//    let storage = try Storage(path: "test.dat")
//    print(storage["hello", String.self])
//    print("Writing")
//    for x in 0..<100_000 {
//        storage["hello \(x)", String.self] = "world \(x)"
//    }
//    print("Waiting")
//}
