import Mastodon
import SwiftUI

struct PagedContentView <Row>: View where Row: View {
    typealias Content = StatusesPagedContent

    @Binding
    var content: Content

    let row: (Binding<Content.Element>) -> Row

    var body: some View {
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
    }

    struct PageView: View {
        typealias Page = Content.Page

        @Binding
        var page: Page

        let row: (Binding<Page.Element>) -> Row

        var body: some View {
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
