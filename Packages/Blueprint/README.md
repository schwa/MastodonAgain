# Blueprint

An experiment in URLRequests.

```swift
Blueprint(.post, "/upload")
.headers {
required("Authorization", "Bearer: \(lookup: "TOKEN")")
}
.query {
}
.body {
Multipart {
"filename": lookup("FILENAME")
}
}
.response(200) {
}
.response(404) {
}
```
