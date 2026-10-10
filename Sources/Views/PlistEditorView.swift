import SwiftUI

struct PlistEditorView: View {
    let url: URL

    @Environment(ToastCenter.self) private var toasts
    @State private var items: [PlistItem] = []
    @State private var original: [PlistItem] = []
    @State private var isDict = true
    @State private var format = PropertyListSerialization.PropertyListFormat.xml
    @State private var loadError: String?

    private var isDirty: Bool { items != original }

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView {
                    Label("plist.unsupported", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                }
            } else {
                PlistContainerView(title: url.lastPathComponent, isDict: isDict, items: $items)
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("action.save", action: save).disabled(!isDirty || loadError != nil)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard original.isEmpty, items.isEmpty else { return }
        do {
            let (value, fmt) = try PlistCodec.read(url)
            format = fmt
            switch value {
            case .dict(let i): isDict = true; items = i
            case .array(let i): isDict = false; items = i
            default: break
            }
            original = items
            loadError = nil
        } catch {
            loadError = RakiError.wrap(error).errorDescription
        }
    }

    private func save() {
        do {
            try PlistCodec.write(isDict ? .dict(items) : .array(items), to: url, format: format)
            original = items
            toasts.success(L("done.saved", url.lastPathComponent))
        } catch {
            toasts.error(error)
        }
    }
}

struct PlistContainerView: View {
    let title: String
    let isDict: Bool
    @Binding var items: [PlistItem]

    @Environment(ToastCenter.self) private var toasts
    @State private var pendingType: PlistType?
    @State private var newKey = ""

    var body: some View {
        List {
            if items.isEmpty {
                Text("plist.empty").foregroundStyle(.secondary)
            }
            ForEach($items) { $item in
                PlistRow(item: $item, label: label(for: item))
            }
            .onDelete { items.remove(atOffsets: $0) }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(PlistType.allCases) { type in
                        Button(LocalizedStringKey(type.titleKey)) { add(type) }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("plist.add_key_title", isPresented: Binding(get: { pendingType != nil }, set: { if !$0 { pendingType = nil } })) {
            TextField("plist.key", text: $newKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("action.add") { commitKey() }
            Button("action.cancel", role: .cancel) {}
        }
    }

    private func label(for item: PlistItem) -> String {
        if isDict { return item.key }
        let idx = items.firstIndex { $0.id == item.id } ?? 0
        return L("plist.item", idx)
    }

    private func add(_ type: PlistType) {
        if isDict {
            newKey = ""
            pendingType = type
        } else {
            items.append(PlistItem(key: "\(items.count)", value: type.defaultValue))
        }
    }

    private func commitKey() {
        guard let type = pendingType else { return }
        let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { toasts.error(RakiError.invalidName); return }
        guard !items.contains(where: { $0.key == key }) else { toasts.error(RakiError.exists(key)); return }
        items.append(PlistItem(key: key, value: type.defaultValue))
    }
}

private struct PlistRow: View {
    @Binding var item: PlistItem
    let label: String

    var body: some View {
        switch item.value {
        case .dict(let children):
            NavigationLink {
                PlistContainerView(title: label, isDict: true, items: Binding(
                    get: { if case .dict(let x) = item.value { return x } else { return [] } },
                    set: { item.value = .dict($0) }))
            } label: { summary(count: children.count) }
        case .array(let children):
            NavigationLink {
                PlistContainerView(title: label, isDict: false, items: Binding(
                    get: { if case .array(let x) = item.value { return x } else { return [] } },
                    set: { item.value = .array($0) }))
            } label: { summary(count: children.count) }
        case .string:
            LabeledContent(label) {
                TextField("plist.value", text: Binding(
                    get: { if case .string(let s) = item.value { return s } else { return "" } },
                    set: { item.value = .string($0) }))
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
        case .integer:
            LabeledContent(label) {
                TextField("plist.value", value: Binding(
                    get: { if case .integer(let i) = item.value { return i } else { return 0 } },
                    set: { item.value = .integer($0) }), format: .number.grouping(.never))
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
            }
        case .real:
            LabeledContent(label) {
                TextField("plist.value", value: Binding(
                    get: { if case .real(let d) = item.value { return d } else { return 0 } },
                    set: { item.value = .real($0) }), format: .number.grouping(.never))
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
            }
        case .bool:
            Toggle(label, isOn: Binding(
                get: { if case .bool(let b) = item.value { return b } else { return false } },
                set: { item.value = .bool($0) }))
        case .date:
            DatePicker(label, selection: Binding(
                get: { if case .date(let d) = item.value { return d } else { return Date() } },
                set: { item.value = .date($0) }))
        case .data(let d):
            LabeledContent(label) { Text(L("plist.data", d.count)).foregroundStyle(.secondary) }
        }
    }

    private func summary(count: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary)
        }
    }
}
