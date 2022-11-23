import Everything
import Foundation
import UniformTypeIdentifiers

public enum BundleSpecifier {
    case main
    case byIdentifier(String)
    case byURL(URL)

    var bundle: Bundle? {
        switch self {
        case .main:
            return Bundle.main
        case .byIdentifier(let identifier):
            return Bundle(identifier: identifier)
        case .byURL(let url):
            return Bundle(url: url)
        }
    }
}

public extension BundleSpecifier {
    init(urlRepresentation: URL) throws {
        // TODO:
        unimplemented()
    }

    var urlRepresentation: URL {
        switch self {
        case .main:
            return URL("x-bundle:?main")
        case .byIdentifier(let identifier):
            return URL("x-bundle:?identifier=\(identifier)")
        case .byURL(let url):
            return URL("x-bundle:?url=\(url)")
        }
    }
}

public enum ResourceSpecifier {
    case bookmark(URLBookmark)
    case url(URL)
    case data(Data, UTType?)
    case bundleResource(BundleSpecifier, String)
}

public extension ResourceSpecifier {
    init(urlRepresentation: URL) throws {
        // TODO:
        unimplemented()
    }

    var urlRepresentation: URL {
        switch self {
        case .bookmark(let bookmark):
            return "x-bookmark:\(bookmark.bookmarkData.base64EncodedString())"
        case .url(let url):
            return url
        case .data(let data, let contentType):
            // https://en.wikipedia.org/wiki/Data_URI_scheme
            let mimeType = contentType?.preferredMIMEType ?? ""
            // If data is URI safe we can skip base64.
            return "data:\(mimeType);base64,\(data.base64EncodedString())"
        case .bundleResource(let specifier, let path):
            return specifier.urlRepresentation.appending(path: path)
        }
    }
}

public extension ResourceSpecifier {
    var resolvedURL: URL? {
        switch self {
        case .bookmark(let bookmark):
            return try? bookmark.resolve().url
        case .url(let url):
            return url
        case .bundleResource(let specifier, let path):
            guard let bundle = specifier.bundle, let resourceURL = bundle.resourceURL else {
                return nil
            }
            return resourceURL.appending(path: path)
        default:
            return nil
        }
    }

    var data: Data {
        get throws {
            switch self {
            case .bookmark(let bookmark):
                let path = try bookmark.resolve()
                return try Data(contentsOf: path.url)
            case .url(let url):
                return try Data(contentsOf: url)
            case .data(let data, _):
                return data
            case .bundleResource(let specifier, let path):
                guard let bundle = specifier.bundle, let resourceURL = bundle.resourceURL else {
                    throw MastodonError.generic("Could not get bundle.")
                }
                let url = resourceURL.appending(path: path)
                return try Data(contentsOf: url)
            }
        }
    }
}
