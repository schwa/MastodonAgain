import Everything
import Foundation
import os
import Security

private let logger: Logger? = Logger()

class MiniKeychain {
}

extension MiniKeychain {
    func savePassword(account: String, password: String) throws {
        DispatchQueue(label: "keychain-write", qos: .default).async {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account,
                kSecValueData as String: password,
            ]
            let status = SecItemAdd(query as CFDictionary, nil)
            switch status {
            case errSecSuccess:
                return
            case errSecDuplicateItem:
                logger?.log("Duplicate - maybe an error?")
                return
            default:
                fatalError("Could not read from keychain")
            }
        }
    }
}

extension MiniKeychain {
    func internetPasswordExists(server: String, account: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            fatalError("Could not read from keychain")
        }
    }

    func saveInternetPassword(server: String, account: String, password: String) throws {
        DispatchQueue(label: "keychain-write", qos: .default).async {
            let query: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrAccount as String: account,
                kSecAttrServer as String: server,
                kSecValueData as String: password,
            ]
            let status = SecItemAdd(query as CFDictionary, nil)
            switch status {
            case errSecSuccess:
                return
            case errSecDuplicateItem:
                logger?.log("Duplicate - maybe an error?")
                return
            default:
                fatalError("Could not read from keychain")
            }
        }
    }

    func removeInternetPassword(forServer server: String, account: String? = nil) throws {
        DispatchQueue(label: "keychain-write", qos: .default).async {
            var query: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: server,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecReturnAttributes as String: true,
                kSecReturnData as String: true,
            ]
            if let account {
                query[kSecAttrAccount as String] = account
            }
            let status = SecItemDelete(query as CFDictionary)
            switch status {
            case errSecSuccess, errSecItemNotFound:
                return
            default:
                fatalError("Could not delete from keychain")
            }
        }
    }

    func internetPassword(forServer server: String, account: String? = nil) throws -> (account: String, password: String)? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let existingItem = item as? [String: Any],
                  let passwordData = existingItem[kSecValueData as String] as? Data,
                  let password = String(data: passwordData, encoding: String.Encoding.utf8),
                  let account = existingItem[kSecAttrAccount as String] as? String
            else {
                return nil
            }
            return (account, password)
        case errSecItemNotFound:
            return nil
        default:
            fatalError("Could not read from keychain")
        }
    }
}

@propertyWrapper
class SecureStorage<Value> {
    var wrappedValue: Value? {
        get {
            do {
                guard let (_, password) = try MiniKeychain().internetPassword(forServer: key) else {
                    return nil
                }
                return reverse(password)
            }
            catch {
                fatalError("Could not read keychain")
            }
        }
        set {
            do {
                if let newValue {
                    let password = converter(newValue)
                    try MiniKeychain().saveInternetPassword(server: key, account: "<fake account>", password: password)
                }
                else {
                    try MiniKeychain().removeInternetPassword(forServer: key)
                }
            }
            catch {
                fatalError("Could not write/delete keychain")
            }
        }
    }

    let key: String
    let converter: (Value) -> String
    let reverse: (String) -> Value

    init(_ key: String, converter: @escaping (Value) -> String, reverse: @escaping (String) -> Value) {
        self.key = key
        self.converter = converter
        self.reverse = reverse
    }
}

extension SecureStorage where Value: Codable {
    convenience init(_ key: String) {
        self.init(key, converter: {
            do {
                return try JSONEncoder().encode($0).base64EncodedString()
            }
            catch {
                fatal(error: error)
            }
        }, reverse: {
            do {
                guard let data = Data(base64Encoded: $0) else {
                    fatalError("Could not base64 encode data.")
                }
                return try JSONDecoder().decode(Value.self, from: data)
            }
            catch {
                fatal(error: error)
            }
        })
    }
}
