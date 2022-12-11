import AsyncAlgorithms
import Blueprint
import Everything
import Foundation
import SwiftUI

public extension Service {
    // TODO: Would love to 'Element' go away here.
    func broadcaster<Element>(for key: BroadcasterKey, element: Element.Type) -> AsyncChannelBroadcaster<Element> where Element: Sendable {
        let broadcaster = broadcasters[key, default: AnyAsyncChannelBroadcaster(AsyncChannelBroadcaster<Element>())]
        broadcasters[key] = broadcaster
        // swiftlint:disable:next force_cast
        return broadcaster.base as! AsyncChannelBroadcaster<Element>
    }
}
