//
//  ContentView.swift
//  Demo
//
//  Created by Jonathan Wight on 11/19/22.
//

import SwiftUI
import Storage

let sharedStorage = {
    print(#function)
    let storage = Storage()
    storage.register(type: String.self) {
        try JSONEncoder().encode($0)
    } decoder: {
        try JSONDecoder().decode(String.self, from: $0)
    }

    try! storage.open(path: "storage.data")
    return storage
}()

struct ContentView: View {

    @State
    var key: String = "MY_KEY"

    @State
    var value: String = ""

    var body: some View {
        VStack {
            TextField("Key", text: .constant(key))
            TextField("Value", text: $value)
            Button("Commit") {
                sharedStorage[key] = value
            }
        }
        .onAppear {
            value = sharedStorage[key] ?? "<nil>"
        }
        .onChange(of: value, perform: { value in
            print("ONCHANGE: \(value)")
            sharedStorage[key] = value
        })
        .onSubmit {
            sharedStorage[key] = value
        }
        .padding()
        .task {
            do {
                for try await _ in try sharedStorage.observe(key) {
                    await MainActor.run {
                        value = sharedStorage[key] ?? "<nil>"
                        print("DID CHANGE: \(value)")
                    }
                }
            }
            catch {
                print(error)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
