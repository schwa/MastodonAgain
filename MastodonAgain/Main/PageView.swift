import SwiftUI


#if os(iOS)
struct PageView <Page, Content>: View where Page: Hashable, Content: View {
    @Binding
    var page: Page

    @ViewBuilder
    let content: () -> Content

    init(page: Binding<Page>, @ViewBuilder content: @escaping () -> Content) {
        // swiftlint:disable:next force_cast
        self._page = page
        self.content = content
    }

    var body: some View {
        TabView(selection: $page, content: content)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .onChange(of: page) { newValue in
            print(newValue)
        }
    }
}

extension View {
    func page <Page>(_ value: Page) -> some View where Page: Hashable {
        self.tag(value)
    }
}

#elseif os(macOS)

public struct PageView <Page, Content>: View where Page: Hashable, Content: View {
    @Binding
    var page: Page

    @ViewBuilder
    var content: () -> Content

    @StateObject
    var model = PageViewModel()

    public init(page: Binding<Page>, @ViewBuilder content: @escaping () -> Content) {
        self._page = page
        self.content = content
    }

    public var body: some View {
        HStack(spacing: 0) {
            content()
        }
        .onChange(of: page) { page in
            model.currentPage = page
        }
        .environmentObject(model)
        .onAppear {
            model.currentPage = page
        }
    }
}

// MARK: -

internal class PageViewModel: ObservableObject {
    @Published
    var pageToIndex: [AnyHashable: Int] = [:]

    @Published
    var currentPage: AnyHashable?
}

// MARK: -

internal struct PageKey: EnvironmentKey {
    static var defaultValue: AnyHashable?
}

internal extension EnvironmentValues {
    var page: AnyHashable? {
        get {
            self[PageKey.self]
        }
        set {
            self[PageKey.self] = newValue
        }
    }
}

internal struct PageModifier <Page>: ViewModifier where Page: Hashable {
    let page: Page

    @EnvironmentObject
    var pageViewModel: PageViewModel

    var isCurrent: Bool {
        pageViewModel.currentPage == AnyHashable(page)
    }

    func body(content: Content) -> some View {
        content
        .removed(!isCurrent)
        .onAppear {
            pageViewModel.pageToIndex[page] = pageViewModel.pageToIndex.count
        }
        .environment(\.page, page)
    }
}

public extension View {
    func page <Page>(_ page: Page) -> some View where Page: Hashable {
        modifier(PageModifier(page: page))
    }
}

#endif

public extension View {
    @ViewBuilder
    func removed(_ removed: Bool = true) -> some View {
        if !removed {
            self
        }
    }
}
