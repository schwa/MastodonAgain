import Mastodon
import SwiftUI

// TODO: Sendable view?
struct PagedContentView <Row, Element>: View where Row: View, Element: Identifiable & Sendable, Element.ID: Comparable & Sendable {
    typealias Content = PagedContent<Element>

    @Binding
    var content: Content

    @Binding
    var isFetching: Bool

    @Environment(\.errorHandler)
    var errorHandler

    @ViewBuilder
    let row: (Binding<Content.Element>) -> Row

    var body: some View {
        Refresh("Newer") {
            fetchPrevious()
        }
        .disabled(content.pages.first?.cursor.previous == nil)
        ForEach(content.pages) { page in
            let id = page.id
            let pageBinding = Binding {
                page
            } set: { newValue in
                guard let index = content.pages.firstIndex(where: { $0.id == id }) else {
                    fatalError("Could not find a page in a timeline we were displaying it from...")
                }
                content.pages[index] = newValue
            }
            PageView(page: pageBinding, row: row)
        }
        Refresh("Older") {
            fetchNext()
        }
        .disabled(content.pages.last?.cursor.next == nil)
    }

    func fetchPrevious() {
        assert(isFetching == false)
        isFetching = true
        guard let fetch = content.pages.first?.cursor.previous else {
            fatalError("No page or not cursor")
        }
        Task {
            await errorHandler {
                let newPage = try await fetch()
                appLogger?.log("Fetched: \(newPage.debugDescription)")
                await MainActor.run {
                    content.pages.insert(newPage, at: 0)
                    isFetching = false
                }
            }
        }
    }

    func fetchNext() {
        guard isFetching == false else {
            return
        }
        isFetching = true
        guard let fetch = content.pages.last?.cursor.next else {
            return
        }
        Task {
            await errorHandler {
                let newPage = try await fetch()
                appLogger?.log("Fetched: \(newPage.debugDescription)")
                await MainActor.run {
                    content.pages.append(newPage)
                    isFetching = false
                }
            }
        }
    }

    struct PageView: View {
        typealias Page = Content.Page

        @Binding
        var page: Page

        let row: (Binding<Page.Element>) -> Row

        var body: some View {
            VStack {
                DebugDescriptionView(page)
            }
            .debuggingInfo()
            ForEach(page.elements) { element in
                let id = element.id
                let binding = Binding {
                    element
                } set: { newValue in
                    guard let index = page.elements.firstIndex(where: { $0.id == id }) else {
                        fatalError("Could not find an element in a page we were displaying it from...")
                    }
                    page.elements[index] = newValue
                }
                row(binding)
            }
        }
    }
}

struct Refresh: View {
    let title: String
    let action: @Sendable () async throws -> Void

    @State
    var running = false

    init(_ title: String, action: @escaping @Sendable () async throws -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        if running {
            ProgressView()
        }
        else {
            Button(title) {
                run()
            }
            .onAppear() {
//                run()
            }
        }
    }

    func run() {
        let action = action
        running = true
        Task.detached {
            try await action()
            running = false
        }
    }
}
