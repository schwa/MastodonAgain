//
//  NavigationSplitViewVisibility+RawRepresentable.swift
//  MastodonAgain
//
//  Created by Sam Deane on 22/11/2022.
//

import SwiftUI

// NavigationSplitViewVisibility is codable, so we should always be
// able to convert it to/from JSON, which means that it can be
// represented as a String... which in turn means that we can store
// it in @AppStorage and/or @SceneStorage
extension NavigationSplitViewVisibility: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8) else {
            return nil
        }
        guard let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return nil
        }
        self = decoded
    }

    public var rawValue: String {
        guard let decoded = try? JSONEncoder().encode(self) else {
            return ""
        }
        return String(data: decoded, encoding: .utf8) ?? ""
    }
}
