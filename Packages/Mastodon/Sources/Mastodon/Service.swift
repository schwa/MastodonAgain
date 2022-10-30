import AsyncAlgorithms
import Everything
import Foundation
import RegexBuilder

public actor Service {
    private var host: String?
    private var token: Token?
    private let session = URLSession.shared
    private let decoder: JSONDecoder

    private var datedStatuses: [Status.ID: Dated<Status>] = [:]
    private var datedAccounts: [Account.ID: Dated<Account>] = [:]

    public init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: string) {
                return date
            }
            formatter.formatOptions.remove(.withFullTime)
            if let date = formatter.date(from: string) {
                return date
            }
            fatalError("Failed to decode date \(string)")
        })
    }

    public func update(host: String?, token: Token?) {
        self.host = host
        self.token = token
    }

    public func favorite(status: Status) async throws {
        guard let host, let token else {
            fatalError("No host or token.")
        }
        let url = URL(string: "https://\(host)/api/v1/statuses/\(status.id)/favourite")!
        let request = URLRequest.post(url).headers(token.headers)
        let (status, response) = try await session.json(Status.self, decoder: decoder, for: request)
        // print(try JSONSerialization.jsonObject(with: data))
//        print(status)
//        print(response)
        update(status)
    }

    public func timelime(_ timeline: Timeline, direction: Timeline.Direction? = nil) async throws -> Timeline {
        guard let host, let token else {
            fatalError("No host or token.")
        }

        let url: URL
        switch direction {
        case nil:
            url = URL(string: "https://\(host)/\(timeline.timelineType.path)")!
        case .previous:
            guard let previous = timeline.previous else {
                print("NO PREVIOUS")
                return timeline
            }
            url = previous
        case .next:
            guard let next = timeline.next else {
                print("NO NEXT")
                return timeline
            }
            url = next
        }

        let request = URLRequest(url: url).headers(token.headers)

        let (data, response) = try await session.validatedData(for: request)

        var previous: URL?
        var next: URL?
        if let link = response.allHeaderFields["Link"] {
            let link = link as! String
            let links = try processLinks(string: link)
            previous = links["prev"]
            next = links["next"]
        }
        else {
            // TODO: Not sure if this is even correct
            print("NO LINK - USING LAST TIMELINE'S")
            previous = timeline.previous
            next = timeline.next
        }
        let statuses = try decoder.decode([Status].self, from: data)
        update(statuses)

        // TODO: Need to sort statuses (or rely on view to do it)
        return Timeline(timelineType: timeline.timelineType, stasuses: timeline.statuses + statuses, previous: previous, next: next)
    }

    public func update(_ value: Status) {
        datedStatuses[value.id] = .init(value)
    }

    public func update(_ other: some Collection<Status>) {
        let now = Date.now
        let other = other.map { Dated($0, date: now) }.map { ($0.content.id, $0) }
        datedStatuses.merge(other) { _, rhs in
            rhs
        }
    }

    public func update(_ value: Account) {
        datedAccounts[value.id] = .init(value)
    }
}

extension URLSession {
    func validatedData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        let httpResponse = response as! HTTPURLResponse
        switch httpResponse.statusCode {
        case 200 ..< 299:
            return (data, httpResponse)
        //    case 401:
        //        throw HTTPError(statusCode: .init(response.statusCode))
        default:
            print(response)
            throw HTTPError(statusCode: .init(httpResponse.statusCode))
        }
    }
}

public struct Timeline: Equatable {
    public enum TimelineType: Equatable {
        case `public`
        case hashtag(String)
        case home
        case list(String) // List.ID

        public var path: URLPath {
            switch self {
            case .public:
                return "/api/v1/timelines/public"
            case .hashtag(let hashtag):
                return "/api/v1/timelines/tag/\(hashtag)"
            case .home:
                return "/api/v1/timelines/home"
            case .list(let list):
                return "/api/v1/timelines/list/\(list)"
            }
        }
    }

    public enum Direction {
        case previous
        case next
    }

    public let timelineType: TimelineType
    public let statuses: [Status]
    public let previous: URL?
    public let next: URL?

    public init(timelineType: Timeline.TimelineType, stasuses: [Status] = [], previous: URL? = nil, next: URL? = nil) {
        self.timelineType = timelineType
        statuses = stasuses
        self.previous = previous
        self.next = next
    }
}

extension Timeline: CustomStringConvertible {
    public var description: String {
        String("Timeline(timelineType: \(timelineType), statuses: \(statuses.count), previous: \(previous), next: \(next)")
    }
}

func processLinks(string: String) throws -> [String: URL] {
    let pattern = #/<(.+?)>;\s*rel="(.+?)", ?/#

    let s = try string.matches(of: pattern).map { match in
        let (_, url, rel) = match.output
        return try (String(rel), URL(string: String(url)).safelyUnwrap(GeneralError.missingValue))
    }
    return Dictionary(uniqueKeysWithValues: s)
}
