// Isolated teaching example. No client dependencies or real patient data.
struct AppointmentDraft {
    var providerName: String
    var patientName: String?
}

var original = AppointmentDraft(providerName: "Dr. A", patientName: nil)
var edited = original
edited.providerName = "Dr. B"

print("struct original: \(original.providerName)")
print("struct edited: \(edited.providerName)")
print("optional fallback: \(original.patientName ?? "Unknown")")

final class AppointmentDraftReference {
    var providerName: String

    init(providerName: String) {
        self.providerName = providerName
    }
}

let first = AppointmentDraftReference(providerName: "Dr. A")
let second = first
second.providerName = "Dr. B"

print("class original: \(first.providerName)")
print("same instance: \(first === second)")
