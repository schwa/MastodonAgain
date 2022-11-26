import AsyncAlgorithms
import Everything
import Foundation
@_implementationOnly import os

// swiftlint:disable file_length

// TODO: Temporary
// swiftlint:disable fatal_error_message

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

public actor Storage {
    let encoders: [TypeID: (Any) throws -> Data]
    let decoders: [TypeID: (Data) throws -> Any]
    let log: StorageLog?
    var channels: [Key: WeakBox<AsyncChannel<Storage.Event>>] = [:]
    var cache: [Key: Record]

    public struct Registration {
        var encoders: [TypeID: (Any) throws -> Data] = [:]
        var decoders: [TypeID: (Data) throws -> Any] = [:]

        public mutating func register<T>(type: T.Type, encoder: @escaping (T) throws -> Data, decoder: @escaping (Data) throws -> T) {
            let type = TypeID(T.self)
            encoders[type] = {
                // swiftlint:disable:next force_cast
                try encoder($0 as! T) // TODO: FIx this
            }
            decoders[type] = {
                try decoder($0)
            }
        }
    }

    public init(path: String, compact: Bool = true, _ closure: (inout Registration) -> Void) throws {
        logger?.log("Opening \(path)")
        var registration = Registration()
        closure(&registration)
        encoders = registration.encoders
        decoders = registration.decoders

        if FileManager().fileExists(atPath: path) {
            var cache: [Key: Record] = [:]
            let data = try StorageLog.read(path: path)
            try data.forEach { key, value in
                let (type, data) = value
                let decoder = try registration.decoders[type].safelyUnwrap(StorageError.noDecoderFound(type))
                do {
                    let value = try decoder(data)
                    cache[key] = Record(type: type, value: .raw(value))
                }
                catch {
                    logger?.error("Failed to decode: \(error)")
                    fatalError()
                }
            }

            if compact {
                log = try Self.compact(path: path, cache: cache, encoders: registration.encoders)
            }
            else {
                log = try .init(path: path)
            }
            self.cache = cache
        }
        else {
            cache = [:]
            log = try .init(path: path)
        }
    }

    /// Note this causes the log to flush so we get an accurate reading.
    public func size() throws -> Int {
        guard let log else {
            fatalError()
        }
        try log.flush()
        // swiftlint:disable:next force_cast
        return try FileManager().attributesOfItem(atPath: log.path)[.size] as! Int
    }

    internal static func compact(path: String, cache: [Key: Record], encoders: [TypeID: (Any) throws -> Data]) throws -> StorageLog {
        let tempPath = try FSPath.makeTemporaryDirectory() / "compacted.data"

        // TODO: This is all rather ugly and likely error prone.
        let newLog = try StorageLog(path: tempPath.path, newSession: false)
        for (key, record) in cache {
            guard let encoder = encoders[record.type] else {
                fatalError("No encoder found")
            }

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
        try newLog.close()

        let oldPath = path
        let newUrl = try FileManager().replaceItemAt(URL(filePath: oldPath), withItemAt: tempPath.url, options: [.withoutDeletingBackupItem, .usingNewMetadataOnly])
        guard let newPath = newUrl?.path else {
            fatalError()
        }

        return try StorageLog(path: newPath)
    }

    public func get<V>(key: some Codable, type: V.Type) throws -> V? where V: Codable {
        let key = try Key(key)
        return try get(key: key, type: type)
    }

    public func get<V>(key: some Codable) throws -> V? where V: Codable {
        let key = try Key(key)
        return try get(key: key, type: V.self)
    }

    public func set(key: some Codable, value: some Codable) throws {
        let key = try Key(key)
        try update(key: key, newValue: value)
    }

    @_spi(SPI)
    public func get<V>(key: Key, type: V.Type) throws -> V? where V: Codable {
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
    public func update<V>(key: Key, newValue: V?) throws where V: Codable {
        guard let log else {
            fatalError()
        }
        let typeID = TypeID(V.self)
        if let newValue {
            cache[key] = Record(type: typeID, value: .raw(newValue))
            guard let encoder = encoders[typeID] else {
                fatalError("No encoder found")
            }
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

@available(*, deprecated, message: "Not safe in actor")
public extension Storage {
    subscript<V>(key: some Codable) -> V? where V: Codable {
        get {
            self[key, V.self]
        }
        set {
            self[key, V.self] = newValue
        }
    }

    subscript<V>(_ key: some Codable, type: V.Type) -> V? where V: Codable {
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

    func observe(_ key: some Codable) throws -> AsyncChannel<Event> {
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

    init(_ key: some Codable) throws {
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
    var open = false
    // TODO: readOnly = false

    init(path: String, newSession: Bool = true) throws {
        self.path = path
        let fd = Darwin.open(path, O_WRONLY | O_CREAT | O_APPEND, 0o755)
        if fd < 0 {
            throw StorageError.fileError(POSIXError(errno)!)
        }
        self.fd = fd
        open = true
        if newSession {
            post {
                .session(UUID(), .now)
            }
        }
    }

    deinit {
        do {
            try close()
        }
        catch {
            logger?.error("Caught error in deinit: \(error)")
        }
    }

    func close() throws {
        guard open == false else {
            return
        }
        try flush()
        Darwin.close(fd)
        open = false
    }

    static func read(path: String) throws -> [Key: (TypeID, Data)] {
        let decoder = JSONDecoder()
        var cache: [Key: (TypeID, Data)] = [:]
        let data = try Data(contentsOf: URL(filePath: path))
        var recordCount = 0
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
                recordCount += 1
            }
        }
        logger?.log("Read \(recordCount) records, got \(cache.count) keys.")
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
                                writev(fd, vectorPointer.baseAddress, Int32(vector.count))
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
