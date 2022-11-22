//
//  BindingAdaptor.swift
//  MastodonAgain
//
//  Created by Sam Deane on 22/11/2022.
//

import SwiftUI

extension Binding where Value: Codable {
    /// Convert a data binding into a codable value binding.
    ///
    /// Encodes/decodes the value on demand.
    init(adapting binding: Binding<Data>, defaultValue: Value) {
        self.init(
                    get: {
                        do {
                            let decoded = try JSONDecoder().decode(Value.self, from: binding.wrappedValue)
                            return decoded
                        } catch {
                            return defaultValue
                        }
                    }, set: { newValue in
                        do {
                            let encoded = try JSONEncoder().encode(newValue)
                            binding.wrappedValue = encoded
                        } catch {
        
                        }
                    })
    }
}


extension Binding where Value == Data {
    /// Convenience method which provides an adaptor binding that translates
    /// to/from data.
    ///
    /// Can be used to put anything codable into @AppStorage or @SceneStorage.
    func adaptor<AdaptedValue: Codable>(defaultValue: AdaptedValue) -> Binding<AdaptedValue> {
        Binding<AdaptedValue>(adapting: self, defaultValue: defaultValue)
    }
}
