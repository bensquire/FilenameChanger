import SwiftUI

/// The list of past renames, newest first, each expandable to its rows.
struct HistoryView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History").font(.headline)
                Spacer()
                // Clearing can't be undone, so the system asks first.
                Button("Clear…", role: .destructive) { confirmingClear = true }
                    .disabled(model.history.isEmpty)
                    .confirmationDialog(
                        "Clear the rename history?", isPresented: $confirmingClear
                    ) {
                        Button("Clear History", role: .destructive) { model.clearHistory() }
                    } message: {
                        Text("The record of past renames is deleted. Your files aren’t changed.")
                    }
                Button("Done") { dismiss() }
            }
            .padding()
            Divider()
            if model.history.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.history) { entry in
                        DisclosureGroup {
                            // By index: an entry's rows never change, and two
                            // rows can carry the same names.
                            ForEach(entry.rows.indices, id: \.self) { index in
                                let row = entry.rows[index]
                                HStack {
                                    Text(row.original).foregroundStyle(.secondary)
                                    Image(systemName: "arrow.right").font(.caption2)
                                    Text(row.renamed)
                                }
                                .font(.callout)
                            }
                        } label: {
                            HStack {
                                Text(entry.date, format: .dateTime)
                                Text("· \(entry.rows.count) files")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 460, height: 420)
    }
}
