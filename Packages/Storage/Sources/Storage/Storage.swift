import AsyncAlgorithms
@_implementationOnly import Everything
import Foundation
@_implementationOnly import os

private let logger: Logger? = Logger()

public enum StorageError: Error {
    @available(*, deprecated, message: "Use more specific errors")
    case generic(String)

    case utfDecodingFailure
    case noDecoderFound(TypeID)
    case noEncoderFound(TypeID)
    case typeFailure(String)
    case fileError(POSIXError)
}

// MARK: -

public class Storage {
    @_spi(SPI)
    public private(set)var cache: [Key: Record] = [:]

    @_spi(SPI)
    public private(set) var log: StorageLog?
    internal var encoders: [TypeID: (Any) throws -> Data] = [:]
    internal var decoders: [TypeID: (Data) throws -> Any] = [:]

    var channels: [Key: WeakBox<AsyncChannel<Storage.Event>>] = [:]

    public init() {
    }

    deinit {
        do {
            try close()
        }
        catch {
            logger?.error("Caught error while closing storage: \(error)")
        }
    }

    public func register<T>(type: T.Type, encoder: @escaping (T) throws -> Data, decoder: @escaping (Data) throws -> T) {
        let type = TypeID(T.self)
        encoders[type] = {
            try encoder($0 as! T)
        }
        decoders[type] = {
            try decoder($0)
        }
    }

    public func open(path: String) throws {
        if FileManager().fileExists(atPath: path) {
            let data = try StorageLog.read(path: path)
            try data.forEach { (key, value) in
                let (type, data) = value
                let decoder = try decoders[type].safelyUnwrap(StorageError.noDecoderFound(type))
                let value = try decoder(data)
                cache[key] = Record(type: type, value: .raw(value))
            }
        }
        log = try .init(path: path)
    }

    public func close() throws {
        log = nil
    }

    /// Note this causes the log to flush so we get an accurate reading.
    public func size() throws -> Int {
        guard let log else {
            fatalError()
        }
        try log.flush()
        return try FileManager().attributesOfItem(atPath: log.path)[.size] as! Int
    }

    public func compact() throws {
        guard let log else {
            fatalError()
        }

        // TODO: This is all rather ugly and likely error prone.
        let tempPath = "/tmp/newlog.data"
        do {
            let newLog = try StorageLog(path: tempPath)
            for (key, record) in cache {
                let encoder = try self.encoders[record.type].safelyUnwrap(StorageError.noEncoderFound(record.type))
                newLog.post {
                    switch record.value {
                    case .raw(let value):
                        let data = try encoder(value)
                        return .set(record.type, key, data)
                    case .encoded(let data):
                        return .set(record.type, key, data)
                    }
                }
            }
        }

        let oldPath = log.path
        let newUrl = try FileManager().replaceItemAt(URL(filePath: oldPath), withItemAt: URL(filePath: tempPath), options: [.withoutDeletingBackupItem, .usingNewMetadataOnly])
        guard let newPath = newUrl?.path else {
            fatalError()
        }

        self.log = try StorageLog(path: newPath)
    }

    @_spi(SPI)
    public func get <V>(key: Key, type: V.Type) throws -> V? where V: Codable {
        guard let record = cache[key] else {
            return nil
        }
        switch record.value {
        case .raw(let value):
            return value as? V
        case .encoded(let data):
            let decoder = try decoders[record.type].safelyUnwrap(StorageError.noDecoderFound(record.type))
            let value = try (decoder(data) as? V).safelyUnwrap(StorageError.typeFailure("Could not cast 'Any' to '\(V.self)'"))
            try update(key: key, newValue: value)
            return value
        }
    }

    @_spi(SPI)
    public func update <V>(key: Key, newValue: V?) throws where V: Codable {
        guard let log else {
            fatalError()
        }
        let typeID = TypeID(V.self)
        if let newValue {
            cache[key] = Record(type: typeID, value: .raw(newValue))
            let encoder = try encoders[typeID].safelyUnwrap(StorageError.noEncoderFound(typeID))
            let data = try encoder(newValue)
            log.post(event: { .set(typeID, key, data) })
            send(key: key, event: .update)
        }
        else {
            cache[key] = nil
            log.post(event: { .delete(typeID, key) })
            send(key: key, event: .remove)
        }
    }

    func send(key: Key, event: Event) {
        guard let box = channels[key] else {
            return
        }
        if let channel = box.content {
            Task {
                await channel.send(event)
            }
        }
        else {
            // Cleanup a box whose content is nil
            channels[key] = nil
        }
    }
}

// MARK: -

public extension Storage {

    subscript<K, V>(key: K) -> Optional<V> where K: Codable, V: Codable {
        get {
            return self[key, V.self]
        }
        set {
            self[key, V.self] = newValue
        }
    }

    subscript<K, V>(_ key: K, type: V.Type) -> Optional<V> where K: Codable, V: Codable {
        get {
            do {
                let key = try Key(key)
                return try get(key: key, type: V.self)
            }
            catch {
                fatal(error: error)
            }
        }
        set {
            do {
                let key = try Key(key)
                try update(key: key, newValue: newValue)
            }
            catch {
                fatal(error: error)
            }
        }
    }
}

public extension Storage {
    enum Event {
        case update
        case remove
    }

    func observe <K>(_ key: K) throws -> AsyncChannel<Event> where K: Codable {
        let key = try Key(key)
        if let channel = channels[key]?.content {
            return channel
        }
        else {
            let channel = AsyncChannel<Event>()
            channels[key] = WeakBox(channel)
            return channel
        }
    }
}

// MARK: -

@_spi(SPI)
public struct Key: Hashable {
    let rawValue: String

    init<T>(_ key: T) throws where T: Codable {
        let data = try JSONEncoder().encode(key)
        let string = try String(data: data, encoding: .utf8).safelyUnwrap(StorageError.utfDecodingFailure)
        rawValue = string
    }
}

extension Key: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

@_spi(SPI)
public struct Record {
    enum Value {
        case encoded(Data)
        case raw(Any)
    }

    let type: TypeID
    let value: Value
}

// MARK: -

@_spi(SPI)
public class StorageLog {
    public enum Event: Codable {
        case session(UUID, Date)
        case set(TypeID, Key, Data)
        case delete(TypeID, Key)
    }

    let path: String
    let fd: Int32
    let encoder = JSONEncoder()
    let queue = DispatchQueue(label: "StorageLog", qos: .default, attributes: [], autoreleaseFrequency: .never, target: nil)
    let group = DispatchGroup()

    init(path: String) throws {
        self.path = path
        let fd = Darwin.open(path, O_WRONLY | O_CREAT | O_APPEND, 0o755)
        if fd < 0 {
            throw StorageError.fileError(POSIXError(errno)!)
        }
        self.fd = fd
        post {
            .session(UUID(), .now)
        }
    }

    deinit {
        do {
            try flush()
            Darwin.close(fd)
        }
        catch {
            logger?.error("Caught error in deinit: \(error)")
        }
    }

    static func read(path: String) throws -> [Key: (TypeID, Data)] {
        let decoder = JSONDecoder()
        var cache: [Key: (TypeID, Data)] = [:]
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
                case .set(let type, let key, let data):
                    cache[key] = (type, data)
                case .delete(_, let key):
                    cache[key] = nil
                case .session(let uuid, let date):
                    logger?.info("Session: \(uuid) \(date)")
                }
            }
        }
        return cache
    }

    public func flush() throws {
        group.wait()
        let result = fcntl(fd, F_FULLFSYNC)
        if result != 0 {
            throw StorageError.fileError(POSIXError(errno)!)
        }
    }

    func post(event: @escaping () throws -> Event) {
        queue.async(group: group) { [encoder, fd] in
            autoreleasepool {
                do {
                    let data = try encoder.encode(event())
                    try withUnsafeBytes(of: data.count) { count in
                        let result = data.withUnsafeBytes { data in
                            let vector = [
                                iovec(iov_base: count.baseAddress, iov_len: count.count),
                                iovec(iov_base: data.baseAddress, iov_len: data.count),
                            ]
                            return vector.withUnsafeBufferPointer { vectorPointer in
                                return writev(fd, vectorPointer.baseAddress, Int32(vector.count))
                            }
                        }
                        guard result > 0 else {
                            throw StorageError.fileError(POSIXError(errno)!)
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
