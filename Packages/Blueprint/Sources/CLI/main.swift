import Blueprint
import Foundation

let accountLookup = Blueprint<()>(path: "/api/v1/accounts/\(lookup: "id")", method: .get)


FileManager().createFile(atPath: "/tmp/test.png", contents: nil)
let body = try MultipartForm(content: ["name": .file(url: URL(filePath: "/tmp/test.png"))])

let accountStatuses = Blueprint<()>(path: "/api/v1/accounts/\(lookup: "id")/statuses", method: .get, headers: [
    "Authorization": .required("Bearer \(lookup: "userToken")")
], body: body)

let r = try URLRequest(url: URL(string: "https://example")!, request: accountStatuses, variables: ["id": "12345", "userToken": "XXX"])
print(r)
