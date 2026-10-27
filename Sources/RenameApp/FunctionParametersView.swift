import RenameKit
import SwiftUI

/// The parameter controls for the currently selected function, laid out as
/// label/input rows (see `row`) that share a fixed `labelWidth` with the
/// function picker above them, so every label and input lines up in one
/// column. Each kind gets just the fields it needs; the model assembles the
/// `RenameFunction` for the live preview.
struct FunctionParametersView: View {
    @Bindable var model: AppModel

    /// Shared label-column width, so the function picker row and every
    /// parameter row line their labels and inputs up in one column.
    static let labelWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.step.kind {
            case .prepend:
                field("Text", text: $model.step.prependText)
            case .append:
                field("Text", text: $model.step.appendText)
            case .replaceFirst, .replaceLast, .replaceAll:
                field("Find", text: $model.step.findText)
                field("Replace with", text: $model.step.replaceText)
            case .wildcard:
                field("Wildcard", text: $model.step.findText, prompt: "e.g. IMG*.JPG")
                field("Replace with", text: $model.step.replaceText)
            case .regex:
                field("Pattern", text: $model.step.findText, prompt: #"e.g. IMG_(\d+)"#)
                field("Template", text: $model.step.replaceText, prompt: "e.g. shot-$1")
            case .removeCharacters:
                removeControls
            case .insertCharacters:
                insertControls
            case .changeCase:
                row("Case") {
                    plainPicker($model.step.textCase, width: 200) { caseOptions { $0 } }
                }
            case .cleanUp:
                cleanUpControls
            case .sequence:
                sequenceControls
            case .date:
                dateControls
            case .smartName:
                smartNameControls
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Remove / Insert

    @ViewBuilder private var removeControls: some View {
        row("Mode") {
            segmented($model.step.removeMode, width: 220) {
                Text("In range").tag(RemoveModeKind.range)
                Text("From end").tag(RemoveModeKind.fromEnd)
            }
        }
        if model.step.removeMode == .range {
            row("Start") { intField($model.step.removeLocation, range: 0...999) }
            row("Length") { intField($model.step.removeLength, range: 1...999) }
        } else {
            row("Count") { intField($model.step.removeFromEnd, range: 1...999) }
        }
    }

    @ViewBuilder private var insertControls: some View {
        field("Text", text: $model.step.insertText)
        row("Where") {
            segmented($model.step.insertMode, width: 220) {
                Text("At index").tag(InsertModeKind.atIndex)
                Text("From end").tag(InsertModeKind.fromEnd)
            }
        }
        if model.step.insertMode == .atIndex {
            row("Index") { intField($model.step.insertIndex, range: 0...999) }
        }
        row("Pad") {
            Toggle("Pad name to length", isOn: $model.step.padEnabled)
            // Always present, disabled when off, so ticking the box doesn't
            // reflow the panel — it just enables the field already in place.
            intField($model.step.padLength, range: 1...999)
                .disabled(!model.step.padEnabled)
        }
    }

    // MARK: - Clean Up

    @ViewBuilder private var cleanUpControls: some View {
        row("Spaces") {
            Toggle("Replace with", isOn: $model.step.cleanUp.replaceSpaces)
            TextField("", text: $model.step.cleanUp.spaceReplacement)
                .frame(width: 56, alignment: .leading)
                .disabled(!model.step.cleanUp.replaceSpaces)
        }
        row("Whitespace") {
            Toggle("Collapse repeated spaces", isOn: $model.step.cleanUp.collapseWhitespace)
        }
        row("Accents") {
            Toggle("Remove accents (é → e)", isOn: $model.step.cleanUp.removeDiacritics)
        }
        row("Characters") {
            Toggle(#"Remove unsafe characters (/ \ : * ? " < > |)"#, isOn: $model.step.cleanUp.removeIllegal)
        }
    }

    // MARK: - Sequence

    @ViewBuilder private var sequenceControls: some View {
        field("Name", text: $model.step.sequence.name)
        row("Name position") {
            segmented($model.step.sequence.namePosition, width: 260) {
                Text("Before digits").tag(NamePosition.before)
                Text("After digits").tag(NamePosition.after)
            }
        }
        row("Digits") {
            Stepper("\(model.step.sequence.digits)", value: $model.step.sequence.digits, in: 1...6)
                .frame(width: 120, alignment: .leading)
        }
        row("Start at") { intField($model.step.sequence.start, range: 0...100000) }
        row("Placement") { placementPicker($model.step.sequence.placement) }
        row("Sort by") {
            plainPicker($model.step.sequence.sort, width: 220) {
                Text("Custom (table order)").tag(SequenceSort.custom)
                Text("Alphabetical").tag(SequenceSort.alphabetical)
                Text("File date").tag(SequenceSort.fileDate)
                Text("EXIF date").tag(SequenceSort.exifDate)
            }
            if model.step.sequence.sort != .custom {
                plainPicker($model.step.sequence.ascending, width: 140) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            }
        }
    }

    // MARK: - Date

    @ViewBuilder private var dateControls: some View {
        row("Source") {
            segmented($model.step.dateSource, width: 280) {
                Text("Custom").tag(DateSourceKind.custom)
                Text("File created").tag(DateSourceKind.fileCreated)
                Text("EXIF").tag(DateSourceKind.exif)
            }
        }
        if model.step.dateSource == .custom {
            row("Date") {
                DatePicker("", selection: $model.step.customDate, displayedComponents: .date)
                    .labelsHidden()
            }
        }
        dateFormatRow($model.step.dateFormat)
        row("Placement") { placementPicker($model.step.datePlacement) }
    }

    // MARK: - Smart Name

    /// The settings show whether or not the model is ready, so a template can
    /// be set up (or saved as a preset) before Apple Intelligence is.
    @ViewBuilder private var smartNameControls: some View {
        field("Template", text: $model.step.smartTemplate, prompt: "{date} - {title}")
        row("") {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    "{date} the document’s date, or the file’s · {title} what it is · {from} who it’s from · {type} Bill, Statement, Letter… · {name} its name now"
                )
                Text("A / files it into a folder there: {from}/{date} - {title}")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        dateFormatRow($model.step.smartDateFormat)
        row("Case") {
            // Applies to what was read ({title}, {from}), not the template's text.
            plainPicker($model.step.smartTextCase, width: 200) {
                Text("As written").tag(TextCase?.none)
                Divider()
                caseOptions { Optional($0) }
            }
        }
        row("") {
            if let explanation = model.analysis.availability.explanation {
                Label(explanation, systemImage: "apple.intelligence")
                    .foregroundStyle(.secondary)
            } else {
                smartNameProgress
            }
        }
    }

    /// How far reading has got, so a long batch visibly moves. Read on device:
    /// say so, as that is what makes handing over documents comfortable.
    @ViewBuilder private var smartNameProgress: some View {
        let pending = model.analysis.pendingCount
        if pending > 0 {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Reading \(pending == 1 ? "1 document" : "\(pending) documents")…")
            }
            .foregroundStyle(.secondary)
        } else {
            Label("Files are read on this Mac by Apple Intelligence.", systemImage: "lock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Building blocks

    /// The Change Case styles as picker items, tagged by `tag`. Shared by
    /// Change Case and Smart Name.
    @ViewBuilder
    private func caseOptions<Tag: Hashable>(_ tag: (TextCase) -> Tag) -> some View {
        Text("Title Case").tag(tag(.title))
        Text("lowercase").tag(tag(.lower))
        Text("UPPERCASE").tag(tag(.upper))
        Divider()
        Text("snake_case").tag(tag(.snake))
        Text("kebab-case").tag(tag(.kebab))
        Text("camelCase").tag(tag(.camel))
        Text("PascalCase").tag(tag(.pascal))
        Text("SCREAMING_SNAKE").tag(tag(.screamingSnake))
    }

    /// A date format: one of the presets, or a pattern typed in. Shared by
    /// Date and Smart Name.
    private func dateFormatRow(_ format: Binding<DateFormatFields>) -> some View {
        row("Format") {
            Toggle("Use preset", isOn: format.usePreset)
            if format.wrappedValue.usePreset {
                plainPicker(format.preset, width: 160) {
                    ForEach(DatePreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
            } else {
                TextField("Pattern", text: format.pattern)
                    .frame(width: 160, alignment: .leading)
            }
        }
    }

    private func placementPicker(_ selection: Binding<Placement>) -> some View {
        segmented(selection, width: 280) {
            Text("Prepend").tag(Placement.prepend)
            Text("Append").tag(Placement.append)
            Text("Replace all").tag(Placement.replaceAll)
        }
    }

    /// A segmented picker with hidden label and an optional fixed, leading-
    /// aligned width — the recurring control shape in this panel.
    @ViewBuilder
    private func segmented<Value: Hashable, Options: View>(
        _ selection: Binding<Value>, width: CGFloat? = nil, @ViewBuilder options: () -> Options
    ) -> some View {
        let picker = Picker("", selection: selection, content: options)
            .labelsHidden()
            .pickerStyle(.segmented)
        if let width {
            picker.frame(width: width, alignment: .leading)
        } else {
            picker
        }
    }

    /// A plain (menu) picker with hidden label and a fixed, leading-aligned
    /// width.
    private func plainPicker<Value: Hashable, Options: View>(
        _ selection: Binding<Value>, width: CGFloat, @ViewBuilder options: () -> Options
    ) -> some View {
        Picker("", selection: selection, content: options)
            .labelsHidden()
            .frame(width: width, alignment: .leading)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String? = nil) -> some View {
        row(label) {
            TextField("", text: text, prompt: prompt.map(Text.init))
                .frame(maxWidth: 320)
                .accessibilityLabel(label)
        }
    }

    private func intField(_ value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 6) {
            TextField("", value: value, format: .number)
                .frame(width: 70, alignment: .leading)
            Stepper("", value: value, in: range).labelsHidden()
        }
    }

    private func row<Content: View>(
        _ label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            RowLabel(label)
            HStack(spacing: 8) { content() }
        }
    }
}

/// A row's label in the panel's label column, so the rows above the
/// parameters line up with them.
struct RowLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(width: FunctionParametersView.labelWidth, alignment: .trailing)
    }
}
