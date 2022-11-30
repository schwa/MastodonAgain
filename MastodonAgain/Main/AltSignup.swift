import Everything
import Mastodon
import SwiftUI

struct AltSignup: View {
    enum Page: Hashable {
        case welcome
        case registerApplication
        case instancePicker
    }

    @State
    var page: Page = .welcome

    var body: some View {
        PagedView(page: $page) {
            VStack {
                Text("Welcome")
                Button("Next") {
                    page = .registerApplication
                }
            }
            .page(Page.welcome)

            RegisterApplicationView(page: $page)
            .page(Page.registerApplication)

            InstancePicker(page: $page)
            .page(Page.instancePicker)
        }
    }
}

struct RegisterApplicationView: View {
    @State
    var applicationName: String = "MastodonAgain-\(Int.random(in: 1 ... 999))"

    @State
    var applicationWebsite: String = "https://github.com/schwa/MastodonAgain"

    @Binding
    var page: AltSignup.Page

    var body: some View {
        VStack {
            Form {
                Text("EXPLANATION HERE")
                Section("Register Application") {
                    LabeledContent("Name") {
                        TextField("application name", text: $applicationName, prompt: Text("application name"))
                            .labelsHidden()
                    }
                    LabeledContent("Website") {
                        TextField("website", text: $applicationWebsite, prompt: Text("website"))
                            .labelsHidden()
                    }
                }
            }

            HStack {
                Button("Back") {
                    page = .welcome
                }

                Button("Save") {
                    UserDefaults.standard.set(applicationName, forKey: "ApplicationName")
                    UserDefaults.standard.set(applicationWebsite, forKey: "ApplicationWebsite")
                    page = .instancePicker
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(applicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .disabled(applicationWebsite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .onAppear {
                applicationName = UserDefaults.standard.string(forKey: "ApplicationName") ?? "MastodonAgain-\(Int.random(in: 1 ... 999))"
                applicationWebsite = UserDefaults.standard.string(forKey: "ApplicationWebsite") ?? "https://github.com/schwa/MastodonAgain"
            }
        }
        .padding()
    }
}

// https://andycroll.com/ruby/convert-iso-country-code-to-emoji-flag/

func emoji_flag(_ code: String) -> String {
    let code = code.uppercased()
    let scalars = code.utf8.map { c in
        Unicode.Scalar(Int(c) + 127397)!
    }
    return String(String.UnicodeScalarView(scalars))
}

struct CountryCodeTag: View {
    let code: String

    init(_ code: String) {
        self.code = code
    }

    var body: some View {
        Text(code.uppercased()).fixedSize().bold()
            .foregroundColor(.white)
            .padding([.top], 4)
            .padding([.bottom], 3)
            .padding([.leading, .trailing], 4)
            .background(Color(web: "#6e6f6e").cornerRadius(4))
            .monospaced()
    }
}

extension Color {
    init(web: String) {
        // swiftlint:disable:next opening_brace
        let pattern = #/^#(?<red>[a-f0-9]{2})(?<green>[a-f0-9]{2})(?<blue>[a-f0-9]{2})$/#
        guard let match = web.firstMatch(of: pattern.ignoresCase()) else {
            fatalError("Oops")
        }
        let (_, redHex, greenHex, blueHex) = match.output

        let red = Double(Int(redHex, radix: 16)!) / 255
        let green = Double(Int(greenHex, radix: 16)!) / 255
        let blue = Double(Int(blueHex, radix: 16)!) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

struct InstancePicker: View {
    @Binding
    var page: AltSignup.Page

    @State
    var instances: [Instance] = []

    @State
    var filtered: [Instance] = []

    init(page: Binding<AltSignup.Page>) {
        self._page = page
    }

    var body: some View {
        VStack {
            List(filtered) { instance in
                LabeledContent {
                    Text("\(instance.info?.shortDescription ?? "")")

                    HStack {
                        ForEach(instance.info?.languages ?? [], id: \.self) {
                            CountryCodeTag($0)
                        }
//                        instance.info?.languages.map(emoji_flag)))")
                    }
                } label: {
                    LabeledContent(instance.name, value: "\(instance.users, format: .number) users")
                        .labeledContentStyle(VerticalLabeledContentStyle())
                }
            }

            HStack {
                Toggle("Open Registrations Only", isOn: .constant(true))
                Toggle("No Dead Instances", isOn: .constant(false))
            }

            Text("\(filtered.count, format: .number)/\(instances.count, format: .number)")
            Button("Back") {
                page = .registerApplication
            }
        }
        .padding()

        .task {
            let url = Bundle.main.url(forResource: "instances", withExtension: "json")!
            let data = try! Data(contentsOf: url)
            struct Container: Decodable {
                let instances: [Instance]
            }
            let decoder = JSONDecoder.mastodonDecoder
            instances = try! decoder.decode(Container.self, from: data).instances
                .sorted(by: \.users)
                .reversed()

            filtered = instances
                .filter { $0.openRegistrations == true }
                .filter { $0.dead == false }
        }
    }
}

// MARK: -

#if os(iOS)
struct PagedView <Page, Content>: View where Page: Hashable, Content: View {
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

struct PagedView <Page, Content>: View where Page: Hashable, Content: View {
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
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HelperView(page: page, content: content)
            }
            .pagedSize(geometry.size)
            .scrollDisabled(true)
        }
    }

    struct HelperView: View {
        let page: Page
        let content: () -> Content

        @Environment(\.pagedSize)
        var pageSize

        var body: some View {
            ScrollViewReader { scroll in
                HStack(spacing: 0) {
                    content()
//                        .border(Color.black)
                }
                .onChange(of: pageSize) { _ in
                    scroll.scrollTo(page, anchor: UnitPoint(x: 0.5, y: 0.5))
                }
                .onChange(of: page) { page in
                    withAnimation {
                        scroll.scrollTo(page, anchor: UnitPoint(x: 0.5, y: 0.5))
                    }
                }
                .onAppear {
                    scroll.scrollTo(page, anchor: UnitPoint(x: 0.5, y: 0.5))
                }
            }
        }
    }
}

// MARK: -

struct PagedItemKey: EnvironmentKey {
    static var defaultValue: AnyHashable?
}

extension EnvironmentValues {
    var page: AnyHashable? {
        get {
            self[PagedItemKey.self]
        }
        set {
            self[PagedItemKey.self] = newValue
        }
    }
}

struct PagedItemModifier <Page>: ViewModifier where Page: Hashable {
    let value: Page

    @Environment(\.pagedSize)
    var pagedSize

    func body(content: Content) -> some View {
        content.environment(\.page, value)
        .id(value)
        .frame(width: pagedSize!.width, height: pagedSize!.height)
    }
}

extension View {
    func page <Page>(_ value: Page) -> some View where Page: Hashable {
        modifier(PagedItemModifier(value: value))
    }
}

// MARK: -

internal struct PagedSizeKey: EnvironmentKey {
    static var defaultValue: CGSize?
}

internal extension EnvironmentValues {
    var pagedSize: CGSize? {
        get {
            self[PagedSizeKey.self]
        }
        set {
            self[PagedSizeKey.self] = newValue
        }
    }
}

internal struct PagedSizeModifier: ViewModifier {
    let value: CGSize
    func body(content: Content) -> some View {
        content.environment(\.pagedSize, value)
    }
}

internal extension View {
    func pagedSize(_ value: CGSize) -> some View {
        self.modifier(PagedSizeModifier(value: value))
    }
}

#endif

struct VerticalLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content.foregroundColor(.secondary)
        }
    }
}

