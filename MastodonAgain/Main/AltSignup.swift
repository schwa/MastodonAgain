import Everything
import Mastodon
import SwiftUI

@MainActor
class AltSignupModel: ObservableObject {
    @Published
    var instances: [Instance] = []
    
    init() {
        Task {
            print("TASK")
            let url = Bundle.main.url(forResource: "instances", withExtension: "json")!
            let data = try! Data(contentsOf: url)
            struct Container: Decodable {
                let instances: [Instance]
            }
            let decoder = JSONDecoder.mastodonDecoder
            await MainActor.run {
                instances = try! decoder.decode(Container.self, from: data).instances
                    .sorted(by: \.users)
                    .reversed()
            }
        }
    }
}

struct AltSignup: View {
    @StateObject
    var model = AltSignupModel()
    
    enum Page: Hashable {
        case welcome
        case registerApplication
        case instancePicker
        case miniInstancePicker
    }
    
    @State
    var page: Page = .miniInstancePicker
    
    var body: some View {
        PageView(page: $page) {
            VStack {
                Text("Welcome")
                TagView("hello world")
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel("hello world")
                Button("Next") {
                    page = .registerApplication
                }
            }
            .page(Page.welcome)
            
            RegisterApplicationView(page: $page)
                .page(Page.registerApplication)
            
            InstancePicker(page: $page)
                .page(Page.instancePicker)
            
            MiniInstancePicker(page: $page)
                .page(Page.miniInstancePicker)
        }
        .environmentObject(model)
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

struct MiniInstancePicker: View {
    @Binding
    var page: AltSignup.Page
    
    @StateObject
    var model = AltSignupModel()
    
    @State
    var host: String = ""
    
    var body: some View {
        
        
        VStack {
            TextField("Host", text: $host)
            HStack {
                let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
                if !host.isEmpty {
                    let hits = model.instances.filter { $0.name.hasPrefix(host) }
                        .prefix(5)
                        .filter { $0.name != host}
                    ForEach(hits) { instance in
                        Button(instance.name) {
                            self.host = instance.name
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
    }
}

struct InstancePicker: View {
    struct Filter: Equatable {
        var openRegistrationsOnly = true
        var noDeadInstances = true
        var language: Locale.Language?
        var maxUsers: Int?
        var minUsers: Int?
        var search: String?
    }
    
    @Binding
    var page: AltSignup.Page
    
    @EnvironmentObject
    var model: AltSignupModel
    
    @State
    var filtered: [Instance] = []
    
    @State
    var selection: Instance.ID?
    
    @State
    var filter = Filter()
    
    init(page: Binding<AltSignup.Page>) {
        self._page = page
    }
    
    var body: some View {
        VStack {
            DebugDescriptionView(filter).lineLimit(5, reservesSpace: true)
            List(filtered, selection: $selection) { instance in
                LabeledContent {
                    VStack(alignment: .leading) {
                        HStack {
                            Spacer()
                            if let shortDescription = instance.info?.shortDescription {
                                Text(shortDescription)
                            }
                            ForEach(instance.info?.languages ?? [], id: \.self) {
                                LanguageCodeTagView($0)
                            }
                        }
                        if selection == instance.id {
                            if let fullDescription = instance.info?.fullDescription {
                                Text(fullDescription)
                            }
                            DebugDescriptionView(instance)
                        }
                    }
                } label: {
                    LabeledContent(instance.name, value: "\(instance.users, format: .number) users")
                        .labeledContentStyle(VerticalLabeledContentStyle())
                }
            }
            
            HStack {
                Button("Back") {
                    page = .registerApplication
                }
                ValueView(false) { isPresentingFilter in
                    Button("Filter…") {
                        isPresentingFilter.wrappedValue = true
                    }
                    .sheet(isPresented: isPresentingFilter) {
                        let allLanguages = model.instances.reduce(into: Set<String>()) { result, instance in
                            result.formUnion(instance.info?.languages ?? [])
                        }
                        InstanceFilterView(isPresenting: isPresentingFilter, filter: $filter, allLanguages: allLanguages)
                    }
                }
                
                Button("Select") {
                    
                }
            }
        }
        .padding()
        .onAppear {
            filterInstances()
        }
        .onChange(of: filter) { _ in
            filterInstances()
        }
        .searchable(text: $filter.search.unwrappingRebound(default: { "" }))
    }
    
    func filterInstances() {
        filtered = model.instances.filter { instance in
            if filter.openRegistrationsOnly && instance.openRegistrations == false {
                return false
            }
            if filter.noDeadInstances && instance.dead == true {
                return false
            }
            if let language = filter.language {
                if (instance.info?.languages ?? []).contains(language.languageCode!.identifier) == false {
                    return false
                }
            }
            if let maxUsers = filter.maxUsers {
                if instance.users > maxUsers {
                    return false
                }
            }
            if let minUsers = filter.minUsers {
                if instance.users < minUsers {
                    return false
                }
            }
            if let search = filter.search?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty {
                if instance.name.localizedCaseInsensitiveContains(search) {
                    return true
                }
                if instance.info?.shortDescription?.localizedCaseInsensitiveContains(search) ?? false {
                    return true
                }
                if instance.info?.fullDescription?.localizedCaseInsensitiveContains(search) ?? false {
                    return true
                }
                if instance.info?.languages.contains(where: { $0.localizedCaseInsensitiveContains(search) }) ?? false {
                    return true
                }
                return false
            }
            
            return true
        }
    }
}

// MARK: -

struct LanguageCodeTagView: View {
    let code: String
    
    init(_ code: String) {
        self.code = code
    }
    
    var longLabel: String {
        let localizedString = Locale.current.localizedString(forLanguageCode: code)
        return localizedString ?? "Language code: \(code)"
    }
    
    var body: some View {
        TagView(code.uppercased())
            .fixedSize()
            .fontWeight(.semibold)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(longLabel)
            .help(longLabel)
    }
}

struct VerticalLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content.foregroundColor(.secondary)
        }
    }
}

struct TagView <Content>: View where Content: View {
    @Environment(\.backgroundStyle)
    var backgroundStyle
    
    let content: Content
    
    init(_ content: Content) {
        self.content = content
    }
    
    var body: some View {
        content.hidden()
            .padding(2)
            .background(backgroundStyle ?? AnyShapeStyle(.gray))
            .mask {
                content
                    .padding(2)
                    .foregroundColor(Color(white: 0))
                    .background(Color(white: 1).cornerRadius(4))
                    .background(Color(white: 0))
                    .compositingGroup()
                    .luminanceToAlpha()
            }
    }
}

extension TagView where Content == Text {
    init(_ label: String) {
        let content = Text(label)
        self.init(content)
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

extension Locale.Language: Identifiable {
    public var id: Locale.LanguageCode {
        languageCode!
    }
}

extension Locale.Language {
    static var all: [Locale.Language] {
        Locale.availableIdentifiers.filter({ !$0.contains("_") }).map { Self(identifier: $0) }
    }
    
    var localizedName: String {
        Locale.current.localizedString(forLanguageCode: languageCode!.identifier)!
    }
}

struct InstanceFilterView: View {
    @Binding
    var isPresenting: Bool
    
    @Binding
    var filter: InstancePicker.Filter
    
    let allLanguages: Set<String>
    
    var body: some View {
        VStack {
            Form {
                Toggle("Open Registrations Only", isOn: $filter.openRegistrationsOnly)
                Toggle("No Dead Instances", isOn: $filter.noDeadInstances)
                
                Picker("Language", selection: $filter.language) {
                    Text("Any").tag(Locale.Language?.none)
                    Divider()
                    ForEach(Locale.Language.all.filter({ allLanguages.contains($0.languageCode!.identifier) }).sorted(by: \.localizedName)) { language in
                        Text("\(language.localizedName) (\(language.languageCode!.identifier))")
                            .tag(Optional(language))
                    }
                }
                
                LabeledContent("# of Users") {
                    TextField("Min", text: Binding(other: $filter.minUsers))
                    TextField("Max", text: Binding(other: $filter.maxUsers))
                }
            }
            
            Button("OK") {
                isPresenting = false
            }
            .keyboardShortcut(.return)
            
        }
        .padding()
    }
}

extension Binding where Value == String {
    init(other: Binding<Int?>) {
        self = .init(get: {
            return other.wrappedValue.map { String($0) } ?? ""
        }, set: { newValue in
            other.wrappedValue = Int(newValue)
        })
    }
    
}
