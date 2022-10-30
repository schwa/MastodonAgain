import Mastodon
import SwiftUI
import Everything

struct TimelineView: View {

    @Environment(\.errorHandler)
    var errorHandler

    @EnvironmentObject
    var appModel: AppModel

    @State
    var timeline: Timeline

    @State
    var refreshing = false

    var body: some View {

        let statuses = timeline.statuses

        List() {
            HStack() {
                Spacer()
                Button("Newer") {
                    refreshTask(direction: .previous)
                }
                .disabled(refreshing)
                Spacer()
            }
            ForEach(statuses) { status in
                StatusRow(status: status)
                Divider()
            }
            HStack() {
                Spacer()
                Button("Older") {
                    refreshTask(direction: .next)
                }
                .disabled(refreshing)
                Spacer()
            }
        }
        .refreshable {
            refreshTask()
        }
        .toolbar {
            Button("Refresh") {
                refreshTask()
            }
            .disabled(refreshing)
        }
        .task {
            refreshTask()
        }
        .onChange(of: timeline) { newValue in
            print(newValue)
        }
    }

    func refreshTask(direction: Timeline.Direction? = nil) {
        refreshing = true
        Task {
            await errorHandler.handle {
                try await refresh(direction: direction)
            }
        }
        refreshing = false
    }

    func refresh(direction: Timeline.Direction? = nil) async throws {
        timeline = try await appModel.service.timelime(timeline, direction: direction)
    }

}

