// A runnable end-to-end walkthrough of the anota API from Swift:
// create a form -> add a field -> publish -> create a submission -> list submissions.
//
// Run it as part of an executable target that depends on AnotaApi, with your key
// in the environment:
//
//   ANOTA_API_KEY=anota_sk_… swift run EndToEnd
//
import Foundation
import AnotaApi

@main
struct EndToEnd {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANOTA_API_KEY"], !apiKey.isEmpty else {
            FileHandle.standardError.write(Data("Set ANOTA_API_KEY to run this example.\n".utf8))
            exit(1)
        }

        let client = AnotaClient(apiKey: apiKey)

        // 1. Create a form with a single text field.
        let created = try await client.createForm(
            title: "Contacto",
            fields: [["type": "text", "label": "Nombre", "required": true]]
        ) as! [String: Any]
        let formId = created["id"] as! String
        print("Created form \(formId)")

        // 2. Add an email field.
        _ = try await client.addFields(
            formId: formId,
            fields: [["type": "email", "label": "Correo", "required": true]]
        )
        print("Added a field")

        // 3. Publish it so it can accept submissions.
        _ = try await client.publishForm(formId: formId)
        print("Published")

        // 4. Create a submission. Answers are keyed by field id.
        let form = try await client.getForm(formId: formId) as! [String: Any]
        let fields = form["fields"] as! [[String: Any]]
        var answers: [String: Any] = [:]
        for field in fields {
            answers[field["id"] as! String] = "ejemplo"
        }
        _ = try await client.createSubmission(formId: formId, answers: answers)
        print("Submitted")

        // 5. List submissions.
        let submissions = try await client.listSubmissions(formId: formId)
        print("Submissions: \(submissions)")
    }
}
