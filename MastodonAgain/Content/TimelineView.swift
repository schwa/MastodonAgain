import Everything
import Mastodon
import SwiftUI
import UniformTypeIdentifiers

// TODO: Sendable view?
struct TimelineView: View, Sendable {
    @Environment(\.errorHandler)
    var errorHandler

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    let timeline: Timeline

    @State
    var content = PagedContent<Service.Fetch>()

    @State
    var refreshing = false

    init(timeline: Timeline) {
        appLogger?.log("INIT (once per timelime)")
        self.timeline = timeline
    }

    @State
    var selection: Set<Status.ID> = []

    @StateObject
    var stackModel = StackModel()

    @ViewBuilder
    var body: some View {
        List(selection: $selection) {
            DebugDescriptionView(timeline.url).debuggingInfo()
            if refreshing {
                ProgressView()
            }

            PagedContentView(content: $content, isFetching: $refreshing) { status in
                StatusRow(status: status, mode: appModel.statusRowMode)
            }
        }
        .toolbar {
            Picker("Mode", selection: $appModel.statusRowMode) {
                Image(systemName: "tablecells").tag(StatusRow.Mode.large)
                Image(systemName: "list.dash").tag(StatusRow.Mode.mini)
            }
            .pickerStyle(.inline)

            ValueView(value: false) { value in
                Button("Save") {
                    value.wrappedValue = true
                }
                // swiftlint:disable:next force_try
                .fileExporter(isPresented: value, document: try! JSONDocument(content), contentType: .json) { result in

                }
            }
        }
        .task {
            appLogger?.log("TASK (once per timelime)")
            refreshTask()
        }
        .onChange(of: content) { newValue in
            appLogger?.log("Content did change")
        }
    }

    func refreshTask(direction: PagingDirection? = nil) {
        appLogger?.log("FETCHING PAGE (once per timelime)")
        guard refreshing == false else {
            return
        }
        refreshing = true
        Task {
            await errorHandler { [instanceModel, timeline] in
                guard await instanceModel.signin.authorization.token != nil else {
                    return
                }
                let page = try await instanceModel.service.timelime(timeline)
                appLogger?.log("Fetched page: \(page.debugDescription)")
                await MainActor.run {
                    content.pages = [page]
                }
            }
            refreshing = false
        }
    }
}

struct JSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init <T>(_ value: T, encoder: JSONEncoder = JSONEncoder()) throws where T: Codable {
        data = try encoder.encode(value)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw MastodonError.generic("Could not read file")
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
