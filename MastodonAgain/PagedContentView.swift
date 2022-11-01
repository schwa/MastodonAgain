import Mastodon
import SwiftUI

struct PagedContentView <Row>: View where Row: View {
    typealias Content = StatusesPagedContent

    @Binding
    var content: Content

    @Binding
    var isFetching: Bool

    @Environment(\.errorHandler)
    var errorHandler

    @ViewBuilder
    let row: (Binding<Content.Element>) -> Row

    var body: some View {
        Button("Newer") {
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
        Button("Older") {
            fetchNext()
        }
        .disabled(content.pages.last?.cursor.next == nil)
    }

    func fetchPrevious() {
        assert(isFetching == false)
        isFetching = true
        guard let fetch = content.pages.last?.cursor.previous else {
            fatalError("No page or not cursor")
        }
        Task {
            await errorHandler.handle {
                let newPage = try await fetch()
                appLogger?.log("Fetched: \(newPage.debugDescription)")
                content.pages.insert(newPage, at: 0)
                isFetching = false
            }
        }
    }

    func fetchNext() {
        assert(isFetching == false)
        isFetching = true
        guard let fetch = content.pages.first?.cursor.next else {
            fatalError("No page or not cursor")
        }
        Task {
            await errorHandler.handle {
                let newPage = try await fetch()
                appLogger?.log("Fetched: \(newPage.debugDescription)")
                content.pages.append(newPage)
                isFetching = false
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
                        fatalError("Could not find am element in a page we were displaying it from...")
                    }
                    page.elements[index] = newValue
                }
                row(binding)
            }
        }
    }
}
