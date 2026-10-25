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
            switch model.kind {
            case .prepend:
                field("Text", text: $model.prependText)
            case .append:
                field("Text", text: $model.appendText)
            case .replaceFirst, .replaceLast, .replaceAll:
                field("Find", text: $model.findText)
                field("Replace with", text: $model.replaceText)
            case .wildcard:
                field("Wildcard", text: $model.findText, prompt: "e.g. IMG*.JPG")
                field("Replace with", text: $model.replaceText)
            case .regex:
                field("Pattern", text: $model.findText, prompt: #"e.g. IMG_(\d+)"#)
                field("Template", text: $model.replaceText, prompt: "e.g. shot-$1")
            case .removeCharacters:
                removeControls
            case .insertCharacters:
                insertControls
            case .changeCase:
                row("Case") {
                    plainPicker($model.textCase, width: 200) {
                        Text("Title Case").tag(TextCase.title)
                        Text("lowercase").tag(TextCase.lower)
                        Text("UPPERCASE").tag(TextCase.upper)
                        Divider()
                        Text("snake_case").tag(TextCase.snake)
                        Text("kebab-case").tag(TextCase.kebab)
                        Text("camelCase").tag(TextCase.camel)
                        Text("PascalCase").tag(TextCase.pascal)
                        Text("SCREAMING_SNAKE").tag(TextCase.screamingSnake)
                    }
                }
            case .cleanUp:
                cleanUpControls
            case .sequence:
                sequenceControls
            case .date:
                dateControls
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Remove / Insert

    @ViewBuilder private var removeControls: some View {
        row("Mode") {
            segmented($model.removeMode, width: 220) {
                Text("In range").tag(RemoveModeKind.range)
                Text("From end").tag(RemoveModeKind.fromEnd)
            }
        }
        if model.removeMode == .range {
            row("Start") { intField($model.removeLocation, range: 0...999) }
            row("Length") { intField($model.removeLength, range: 1...999) }
        } else {
            row("Count") { intField($model.removeFromEnd, range: 1...999) }
        }
    }

    @ViewBuilder private var insertControls: some View {
        field("Text", text: $model.insertText)
        row("Where") {
            segmented($model.insertMode, width: 220) {
                Text("At index").tag(InsertModeKind.atIndex)
                Text("From end").tag(InsertModeKind.fromEnd)
            }
        }
        if model.insertMode == .atIndex {
            row("Index") { intField($model.insertIndex, range: 0...999) }
        }
        row("Pad") {
            Toggle("Pad name to length", isOn: $model.padEnabled)
            // Always present, disabled when off, so ticking the box doesn't
            // reflow the panel — it just enables the field already in place.
            intField($model.padLength, range: 1...999)
                .disabled(!model.padEnabled)
        }
    }

    // MARK: - Clean Up

    @ViewBuilder private var cleanUpControls: some View {
        row("Spaces") {
            Toggle("Replace with", isOn: $model.cleanUp.replaceSpaces)
            TextField("", text: $model.cleanUp.spaceReplacement)
                .frame(width: 56, alignment: .leading)
                .disabled(!model.cleanUp.replaceSpaces)
        }
        row("Whitespace") {
            Toggle("Collapse repeated spaces", isOn: $model.cleanUp.collapseWhitespace)
        }
        row("Accents") {
            Toggle("Remove accents (é → e)", isOn: $model.cleanUp.removeDiacritics)
        }
        row("Characters") {
            Toggle(#"Remove unsafe characters (/ \ : * ? " < > |)"#, isOn: $model.cleanUp.removeIllegal)
        }
    }

    // MARK: - Sequence

    @ViewBuilder private var sequenceControls: some View {
        field("Name", text: $model.sequence.name)
        row("Name position") {
            segmented($model.sequence.namePosition, width: 260) {
                Text("Before digits").tag(NamePosition.before)
                Text("After digits").tag(NamePosition.after)
            }
        }
        row("Digits") {
            Stepper("\(model.sequence.digits)", value: $model.sequence.digits, in: 1...6)
                .frame(width: 120, alignment: .leading)
        }
        row("Start at") { intField($model.sequence.start, range: 0...100000) }
        row("Placement") { placementPicker($model.sequence.placement) }
        row("Sort by") {
            plainPicker($model.sequence.sort, width: 220) {
                Text("Custom (table order)").tag(SequenceSort.custom)
                Text("Alphabetical").tag(SequenceSort.alphabetical)
                Text("File date").tag(SequenceSort.fileDate)
                Text("EXIF date").tag(SequenceSort.exifDate)
            }
            if model.sequence.sort != .custom {
                plainPicker($model.sequence.ascending, width: 140) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            }
        }
    }

    // MARK: - Date

    @ViewBuilder private var dateControls: some View {
        row("Source") {
            segmented($model.dateSource, width: 280) {
                Text("Custom").tag(DateSourceKind.custom)
                Text("File created").tag(DateSourceKind.fileCreated)
                Text("EXIF").tag(DateSourceKind.exif)
            }
        }
        if model.dateSource == .custom {
            row("Date") {
                DatePicker("", selection: $model.customDate, displayedComponents: .date)
                    .labelsHidden()
            }
        }
        row("Format") {
            Toggle("Use preset", isOn: $model.usePresetDate)
            if model.usePresetDate {
                plainPicker($model.datePreset, width: 160) {
                    ForEach(DatePreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
            } else {
                TextField("Pattern", text: $model.customDatePattern)
                    .frame(width: 160, alignment: .leading)
            }
        }
        row("Placement") { placementPicker($model.datePlacement) }
    }

    // MARK: - Building blocks

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
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: Self.labelWidth, alignment: .trailing)
            HStack(spacing: 8) { content() }
        }
    }
}
