# anota-api-ios · Official Swift client for the [anota](https://anota.cloud) API

**[Léeme en español](README.es.md)** · [Interactive API reference](https://anota.cloud/developers) · [All SDKs](https://github.com/anotacloud/anota-api)

![CI](https://github.com/anotacloud/anota-api-ios/actions/workflows/ci.yml/badge.svg)

Create and publish forms, edit fields and conditional logic, read and write
submissions, and wire webhooks — everything the anota REST API can do, from Swift.

It is a thin, dependency-free wrapper over `URLSession`: every method returns the
server's JSON parsed by `JSONSerialization` into a generic value
(`[String: Any]`, `[Any]`, or `NSNull` for empty bodies). Works on iOS 15+ and
macOS 12+, and is `async`/`await` throughout.

## Install

Swift Package Manager. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/anotacloud/anota-api-ios", from: "1.0.0")
]
```

or add it in Xcode via **File ▸ Add Package Dependencies…** with the URL
`https://github.com/anotacloud/anota-api-ios`.

Or download the [ZIP](https://github.com/anotacloud/anota-api-ios/archive/refs/heads/main.zip)
/ [Tarball](https://github.com/anotacloud/anota-api-ios/archive/refs/heads/main.tar.gz).

## Quickstart

```swift
import AnotaApi

let client = AnotaClient(apiKey: ProcessInfo.processInfo.environment["ANOTA_API_KEY"]!)

// Create a form with one text field, publish it, and read its submissions.
let form = try await client.createForm(
    title: "Contacto",
    fields: [["type": "text", "label": "Nombre", "required": true]]
) as! [String: Any]
let formId = form["id"] as! String

try await client.publishForm(formId: formId)

let submissions = try await client.listSubmissions(formId: formId)
print(submissions)
```

## Authentication

Create an API key in your workspace at https://anota.cloud/api-keys and pass it to
the client. Keys look like `anota_sk_…` and also power the Claude MCP connector.

```swift
let client = AnotaClient(apiKey: "anota_sk_…")
// Point at a different environment if needed:
let staging = AnotaClient(apiKey: "anota_sk_…", baseUrl: "https://staging.anota.cloud/api/v1")
```

## All methods

Every method is `async` and `throws`; JSON objects are passed as
`[String: Any]` and arrays of them as `[[String: Any]]`.

| # | Method | HTTP |
|---|---|---|
| 1 | `listForms()` | `GET /forms` |
| 2 | `createForm(title:fields:description:)` | `POST /forms` |
| 3 | `getForm(formId:)` | `GET /forms/{formId}` |
| 4 | `addFields(formId:fields:)` | `POST /forms/{formId}/fields` |
| 5 | `editField(formId:fieldId:field:)` | `PATCH /forms/{formId}/fields/{fieldId}` |
| 6 | `deleteField(formId:fieldId:)` | `DELETE /forms/{formId}/fields/{fieldId}` |
| 7 | `publishForm(formId:)` | `POST /forms/{formId}/publish` |
| 8 | `renameForm(formId:title:)` | `PATCH /forms/{formId}` |
| 9 | `setPdfTemplate(formId:key:)` | `PUT /forms/{formId}/pdf-template` |
| 10 | `deleteForm(formId:)` | `DELETE /forms/{formId}` |
| 11 | `cloneForm(formId:)` | `POST /forms/{formId}/clone` |
| 12 | `addLogicRules(formId:rules:)` | `POST /forms/{formId}/logic-rules` |
| 13 | `editLogicRule(formId:ruleId:rule:)` | `PUT /forms/{formId}/logic-rules/{ruleId}` |
| 14 | `deleteLogicRule(formId:ruleId:)` | `DELETE /forms/{formId}/logic-rules/{ruleId}` |
| 15 | `listSubmissions(formId:page:pageSize:status:)` | `GET /forms/{formId}/submissions` |
| 16 | `getSubmission(submissionId:)` | `GET /submissions/{submissionId}` |
| 17 | `createSubmission(formId:answers:)` | `POST /forms/{formId}/submissions` |
| 18 | `setSubmissionStatus(submissionId:status:)` | `PATCH /submissions/{submissionId}/status` |
| 19 | `deleteSubmission(submissionId:)` | `DELETE /submissions/{submissionId}` |
| 20 | `submissionStats(formId:)` | `GET /forms/{formId}/stats` |
| 21 | `listTemplates(language:)` | `GET /templates` |
| 22 | `createFormFromTemplate(templateId:)` | `POST /forms/from-template/{templateId}` |
| 23 | `listWebhooks(formId:)` | `GET /forms/{formId}/webhooks` |
| 24 | `addWebhook(formId:url:)` | `POST /forms/{formId}/webhooks` |
| 25 | `deleteWebhook(formId:webhookId:)` | `DELETE /forms/{formId}/webhooks/{webhookId}` |

A field is a plain dictionary: `["type": …, "label": …, "required": …, "options": …, "rows": …, "columns": …]`.
A logic rule is `["match": "all"|"any", "if": [...], "then": [...]]`. Submission
`answers` are keyed by field id, with string or string-array values.

See a full walkthrough in [`examples/EndToEnd.swift`](examples/EndToEnd.swift).

## Errors

Non-2xx responses throw `AnotaApiError` with the HTTP `status` and the server's
`message`. Network failures surface as the platform's native `URLError`, not
`AnotaApiError`.

```swift
do {
    try await client.publishForm(formId: formId)
} catch let error as AnotaApiError {
    print("anota returned \(error.status): \(error.message)")
}
```

Note: once a form has been published, its existing fields are locked
(`editField`/`deleteField` return 400); you can always `addFields`.

## License

MIT
