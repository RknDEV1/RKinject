import SwiftUI

struct SourcesView: View {
    @Environment(SourcesStore.self) private var store
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section("sources.this_app") {
                    ForEach(store.builtin) { row($0) }
                }
                if !store.groups.isEmpty {
                    Section("sources.groups") {
                        ForEach(store.groups) { row($0) }
                    }
                }
                Section {
                    ForEach(store.custom) { row($0) }
                        .onDelete { store.removeCustom(at: $0) }
                } header: {
                    Text("sources.custom")
                } footer: {
                    Text("sources.add_hint")
                }
            }
            .navigationTitle("sources.title")
            .navigationDestination(for: FileSource.self) { src in
                FileBrowserView(url: URL(fileURLWithPath: src.path), title: src.name)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddSourceView() }
        }
    }

    @ViewBuilder
    private func row(_ src: FileSource) -> some View {
        if src.isAvailable {
            NavigationLink(value: src) { label(src) }
        } else {
            label(src).foregroundStyle(.secondary)
        }
    }

    private func label(_ src: FileSource) -> some View {
        HStack(spacing: 12) {
            Image(systemName: src.symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(src.name).lineLimit(1)
                if !src.isAvailable {
                    Text("sources.group_unavailable").font(.caption)
                } else if src.isCustom {
                    Text(src.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }
}

struct AddSourceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SourcesStore.self) private var store
    @Environment(ToastCenter.self) private var toasts
    @State private var name = ""
    @State private var path = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("sources.name", text: $name)
                    TextField("sources.path", text: $path)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("sources.add_hint")
                }
            }
            .navigationTitle("sources.add_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.add") {
                        do { try store.addCustom(name: name, path: path); dismiss() }
                        catch { toasts.error(error) }
                    }
                    .disabled(path.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
