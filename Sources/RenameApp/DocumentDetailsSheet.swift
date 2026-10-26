import RenameIntelligence
import RenameKit
import SwiftUI

/// Smart Name's findings for one file, to correct by hand: the model read a
/// title or a sender wrong, or couldn't read the file at all. What is saved
/// replaces what was read, so the template keeps filling the name from it.
struct DocumentDetailsSheet: View {
    let fileName: String
    let onSave: (DocumentSummary) -> Void

    @State private var title: String
    @State private var from: String
    @State private var type: String
    @State private var date: Date

    /// Starts from what was read, or, for a file that couldn't be, empty with
    /// the file's own date — the date a read file falls back to.
    init(
        fileName: String, summary: DocumentSummary?, fileDate: Date?,
        onSave: @escaping (DocumentSummary) -> Void
    ) {
        self.fileName = fileName
        self.onSave = onSave
        _title = State(initialValue: summary?.title ?? "")
        _from = State(initialValue: summary?.from ?? "")
        _type = State(initialValue: summary?.type ?? "")
        _date = State(initialValue: summary?.date ?? fileDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Name Details").font(.headline)
                Text(fileName).foregroundStyle(.secondary)
            }
            Form {
                TextField("Title", text: $title, prompt: Text("Electricity Bill"))
                TextField("From", text: $from, prompt: Text("Who sent it"))
                LabeledContent("Type") {
                    HStack(spacing: 6) {
                        TextField("Type", text: $type, prompt: Text("Bill"))
                            .labelsHidden()
                        // The model's own list, so a corrected row sorts with the rest.
                        Menu("Types") {
                            ForEach(DocumentType.names, id: \.self) { name in
                                Button(name) { type = name }
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .formStyle(.grouped)
            .frame(width: 420)
            SheetButtons("Save", isDisabled: trimmed(title) == nil) { onSave(summary) }
        }
        .padding(20)
    }

    /// What was typed, as Smart Name reads it: blank fields are nothing, and
    /// the date is noon that day, as a read date is, so it formats as that
    /// day in every time zone.
    private var summary: DocumentSummary {
        let noon = Calendar.autoupdatingCurrent.date(bySettingHour: 12, minute: 0, second: 0, of: date)
        return DocumentSummary(
            title: trimmed(title) ?? "", from: trimmed(from), type: trimmed(type), date: noon ?? date)
    }

    private func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
