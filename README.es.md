# anota-api-ios · Cliente oficial de Swift para la API de [anota](https://anota.cloud)

**[Read me in English](README.md)** · [Referencia interactiva de la API](https://anota.cloud/developers) · [Todos los SDKs](https://github.com/anotacloud/anota-api)

![CI](https://github.com/anotacloud/anota-api-ios/actions/workflows/ci.yml/badge.svg)

Crea y publica formularios, edita campos y lógica condicional, lee y escribe
respuestas, y conecta webhooks — todo lo que la API REST de anota puede hacer,
desde Swift.

Es un envoltorio ligero y sin dependencias sobre `URLSession`: cada método
devuelve el JSON del servidor procesado por `JSONSerialization` como un valor
genérico (`[String: Any]`, `[Any]`, o `NSNull` para cuerpos vacíos). Funciona en
iOS 15+ y macOS 12+, y usa `async`/`await` en su totalidad.

## Instalación

Swift Package Manager. En `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/anotacloud/anota-api-ios", from: "1.0.0")
]
```

o añádelo en Xcode con **File ▸ Add Package Dependencies…** usando la URL
`https://github.com/anotacloud/anota-api-ios`.

O descarga el [ZIP](https://github.com/anotacloud/anota-api-ios/archive/refs/heads/main.zip)
/ [Tarball](https://github.com/anotacloud/anota-api-ios/archive/refs/heads/main.tar.gz).

## Inicio rápido

```swift
import AnotaApi

let client = AnotaClient(apiKey: ProcessInfo.processInfo.environment["ANOTA_API_KEY"]!)

// Crea un formulario con un campo de texto, publícalo y lee sus respuestas.
let form = try await client.createForm(
    title: "Contacto",
    fields: [["type": "text", "label": "Nombre", "required": true]]
) as! [String: Any]
let formId = form["id"] as! String

try await client.publishForm(formId: formId)

let submissions = try await client.listSubmissions(formId: formId)
print(submissions)
```

## Autenticación

Crea una clave de API en tu workspace en https://anota.cloud/api-keys y pásala al
cliente. Las claves tienen el formato `anota_sk_…` y también habilitan el conector
MCP de Claude.

```swift
let client = AnotaClient(apiKey: "anota_sk_…")
// Apunta a otro entorno si lo necesitas:
let staging = AnotaClient(apiKey: "anota_sk_…", baseUrl: "https://staging.anota.cloud/api/v1")
```

## Todos los métodos

Cada método es `async` y `throws`; los objetos JSON se pasan como
`[String: Any]` y los arreglos de ellos como `[[String: Any]]`.

| # | Método | HTTP |
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

**El secreto de firma del webhook se muestra una sola vez.** `addWebhook(formId:url:)` devuelve el `secret` completo (`whsec_…`) en su respuesta (`id`, `formId`, `url`, `secret`, `note`): guárdalo en ese momento. `listWebhooks(formId:)` nunca lo devuelve: cada fila trae `secretHint` (`whsec_…` más los últimos 4 caracteres, o solo `whsec_…` si el secreto es corto) y `secretNote` en lugar de `secret`. Si lo pierdes, elimina el webhook y vuelve a agregarlo para obtener un secreto nuevo. Consulta [CHANGELOG.md](CHANGELOG.md).

Un campo es un diccionario simple: `["type": …, "label": …, "required": …, "options": …, "rows": …, "columns": …]`.
Una regla de lógica es `["match": "all"|"any", "if": [...], "then": [...]]`. Las
respuestas (`answers`) se indexan por id de campo, con valores de texto o arreglo
de texto.

Consulta un recorrido completo en [`examples/EndToEnd.swift`](examples/EndToEnd.swift).

## Errores

Las respuestas que no son 2xx lanzan `AnotaApiError` con el `status` HTTP y el
`message` del servidor. Los fallos de red se propagan como el `URLError` nativo de
la plataforma, no como `AnotaApiError`.

```swift
do {
    try await client.publishForm(formId: formId)
} catch let error as AnotaApiError {
    print("anota devolvió \(error.status): \(error.message)")
}
```

Nota: una vez que un formulario se ha publicado, sus campos existentes quedan
bloqueados (`editField`/`deleteField` devuelven 400); siempre puedes usar
`addFields`.

## Licencia

MIT
