import Everything
import Mastodon
import SwiftUI

struct AppSettings: View {
    @EnvironmentObject
    var appModel: AppModel

    struct Tab: CaseIterable, Identifiable, Hashable {
        var id: String {
            title
        }

        let title: String
        let systemImage: String

        static let application = Tab(title: "Application", systemImage: "app")
        static let accounts = Tab(title: "Accounts", systemImage: "person.2")
        static let misc = Tab(title: "Misc", systemImage: "gear")

        static var allCases: [AppSettings.Tab] {
            [.application, .accounts, .misc]
        }
    }

    @State
    var selection: Tab? = Tab.application

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                Label(tab.title, systemImage: tab.systemImage).tag(tab)
            }
        }
        detail: {
            if let selection {
                content(for: selection)
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        #if os(macOS)
            .toolbar(.hidden, for: .windowToolbar)
        #endif
    }

    @ViewBuilder
    func content(for tab: Tab) -> some View {
        GroupBox(tab.title) {
            switch tab {
            case .application:
                application
            case .accounts:
                accounts
            case .misc:
                misc
            default:
                PlaceholderShape().stroke()
            }
        }
        .groupBoxStyle(MyGroupBoxStyle())
        .padding()
    }

    @ViewBuilder
    var application: some View {
        List {
            Form {
                TextField("Name", text: $appModel.applicationName)
                TextField("Website", text: $appModel.applicationWebsite)
                Text("Application name and website are only used when logging in to a new instance.").font(.caption)
                #if os(macOS)
                    Button("Reveal Application Support Directory") {
                        FSPath.applicationSupportDirectory!.reveal()
                    }
                    Button("Reveal Preferences") {
                        (FSPath.libraryDirectory! / "Preferences/io.schwa.MastodonAgain.plist").reveal()
                    }
                #endif
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    var accounts: some View {
        SigninsView()
    }

    @ViewBuilder
    var misc: some View {
        List {
            Form {
                Toggle("Hide Sensitive Content", isOn: $appModel.hideSensitiveContent)
                Toggle("Show Account Handles", isOn: $appModel.showAccountHandles)
                Toggle("Show Debugging Info", isOn: $appModel.showDebuggingInfo)
                Toggle("Use Markdown Content (Very Experimental)", isOn: $appModel.useMarkdownContent)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct MyGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        GroupBox {
            configuration.content
        } label: {
            configuration.label.font(.headline)
        }
        .groupBoxStyle(.automatic)
    }
}
