import SwiftUI
import QuickLook

struct FileBrowserView: View {
    let url: URL
    let title: String

    @Environment(FileClipboard.self) private var clipboard
    @Environment(ToastCenter.self) private var toasts
    @AppStorage("showHidden") private var showHidden = false

    @State private var items: [FileItem] = []
    @State private var results: [FileItem] = []
    @State private var query = ""
    @State private var sort: FileSort = .name
    @State private var loadError: String?
    @State private var isWorking = false

    @State private var showImporter = false
    @State private var previewURL: URL?
    @State private var plistTarget: URL?
    @State private var renameTarget: FileItem?
    @State private var renameText = ""
    @State private var deleteTarget: FileItem?
    @State private var showNewFolder = false
    @State private var folderName = ""

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    private var displayed: [FileItem] { isSearching ? results : sorted(items) }

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView {
                    Label("files.error_title", systemImage: "lock.fill")
                } description: {
                    Text(loadError)
                }
            } else if displayed.isEmpty {
                if isSearching {
                    ContentUnavailableView.search(text: query)
                } else {
                    ContentUnavailableView("files.empty", systemImage: "folder", description: Text("files.empty_hint"))
                }
            } else {
                List(displayed) { item in row(item) }
                    .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: Text("files.search"))
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { if !clipboard.urls.isEmpty { pasteBar } }
        .overlay { if isWorking { workingOverlay } }
        .onAppear(perform: reload)
        .onChange(of: showHidden) { reload() }
        .task(id: query) { await runSearch() }
        .quickLookPreview($previewURL)
        .navigationDestination(item: $plistTarget) { PlistEditorView(url: $0) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): importFiles(urls)
            case .failure(let error): toasts.error(error)
            }
        }
        .confirmationDialog("confirm.delete_title",
                            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible, presenting: deleteTarget) { item in
            Button("action.delete", role: .destructive) {
                run(L("done.deleted", item.name)) { try FileService.delete(item.url) }
            }
        } message: { item in
            Text(L("confirm.delete_message", item.name))
        }
        .alert("rename.title", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } }),
               presenting: renameTarget) { item in
            TextField("rename.placeholder", text: $renameText)
            Button("action.save") {
                let text = renameText
                run(L("done.renamed", text)) { try FileService.rename(item.url, to: text) }
            }
            Button("action.cancel", role: .cancel) {}
        }
        .alert("files.new_folder", isPresented: $showNewFolder) {
            TextField("files.folder_name", text: $folderName)
            Button("action.create") {
                let name = folderName
                run(L("done.folder", name)) { try FileService.makeFolder(named: name, in: url) }
            }
            Button("action.cancel", role: .cancel) {}
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func row(_ item: FileItem) -> some View {
        let subtitle = isSearching ? relativePath(item.url) : nil
        Group {
            if item.isDirectory {
                NavigationLink {
                    FileBrowserView(url: item.url, title: item.name)
                } label: {
                    FileRow(item: item, subtitle: subtitle)
                }
            } else {
                Button { open(item) } label: {
                    FileRow(item: item, subtitle: subtitle)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu { menu(for: item) }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleteTarget = item } label: { Label("action.delete", systemImage: "trash") }
            Button { beginRename(item) } label: { Label("action.rename", systemImage: "pencil") }.tint(.indigo)
        }
    }

    @ViewBuilder
    private func menu(for item: FileItem) -> some View {
        if !item.isDirectory {
            Button { previewURL = item.url } label: { Label("action.preview", systemImage: "eye") }
            if item.ext == "plist" {
                Button { plistTarget = item.url } label: { Label("action.open_plist", systemImage: "list.bullet.rectangle") }
            }
        }
        Button { clipboard.set([item.url], mode: .copy) } label: { Label("action.copy", systemImage: "doc.on.doc") }
        Button { clipboard.set([item.url], mode: .move) } label: { Label("action.move", systemImage: "folder") }
        Button { beginRename(item) } label: { Label("action.rename", systemImage: "pencil") }
        if !item.isDirectory {
            ShareLink(item: item.url) { Label("action.share", systemImage: "square.and.arrow.up") }
        }
        Button {
            run(L("done.zipped", item.name)) { try FileService.zip(item.url) }
        } label: { Label("action.zip", systemImage: "doc.zipper") }
        if item.ext == "zip" {
            Button {
                run(L("done.unzipped", item.name)) { try FileService.unzip(item.url) }
            } label: { Label("action.unzip", systemImage: "arrow.up.bin") }
        }
        Divider()
        Button(role: .destructive) { deleteTarget = item } label: { Label("action.delete", systemImage: "trash") }
    }

    // MARK: Toolbar and bars

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("files.sort", selection: $sort) {
                    ForEach(FileSort.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
                }
                Toggle("files.show_hidden", isOn: $showHidden)
                Divider()
                Button { folderName = ""; showNewFolder = true } label: { Label("files.new_folder", systemImage: "folder.badge.plus") }
                Button { showImporter = true } label: { Label("files.import", systemImage: "square.and.arrow.down") }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var pasteBar: some View {
        HStack(spacing: 12) {
            Image(systemName: clipboard.mode == .copy ? "doc.on.doc.fill" : "folder.fill").foregroundStyle(Color.accentColor)
            Text(L(clipboard.mode == .copy ? "files.paste_copy" : "files.paste_move", clipboard.urls.count))
                .font(.subheadline).lineLimit(1)
            Spacer()
            Button("action.cancel") { clipboard.clear() }.buttonStyle(.bordered).controlSize(.small)
            Button("files.paste") { paste() }.buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var workingOverlay: some View {
        ProgressView()
            .controlSize(.large)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Logic

    private func sorted(_ list: [FileItem]) -> [FileItem] {
        list.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            switch sort {
            case .name: return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .date: return (a.modified ?? .distantPast) > (b.modified ?? .distantPast)
            case .size: return a.size > b.size
            }
        }
    }

    private func relativePath(_ u: URL) -> String {
        let base = url.standardizedFileURL.path
        let full = u.deletingLastPathComponent().standardizedFileURL.path
        let rel = full.hasPrefix(base) ? String(full.dropFirst(base.count)) : full
        return rel.isEmpty ? "/" : rel
    }

    private func reload() {
        do {
            items = try FileService.list(url, showHidden: showHidden)
            loadError = nil
        } catch {
            items = []
            loadError = RakiError.wrap(error).errorDescription
        }
    }

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        try? await Task.sleep(for: .milliseconds(250))          // debounce
        guard !Task.isCancelled else { return }
        let found = await FileService.search(root: url, query: q, showHidden: showHidden)
        if !Task.isCancelled { results = found }
    }

    private func open(_ item: FileItem) {
        if item.ext == "plist" { plistTarget = item.url } else { previewURL = item.url }
    }

    private func beginRename(_ item: FileItem) {
        renameText = item.name
        renameTarget = item
    }

    private func paste() {
        let urls = clipboard.urls
        let mode = clipboard.mode
        let dest = url
        clipboard.clear()
        run(L(mode == .copy ? "done.copied" : "done.moved", urls.count)) {
            if mode == .copy { try FileService.copy(urls, to: dest) } else { try FileService.move(urls, to: dest) }
        }
    }

    private func importFiles(_ urls: [URL]) {
        let dest = url
        run(L("done.imported", urls.count)) {
            for u in urls {
                let ok = u.startAccessingSecurityScopedResource()
                defer { if ok { u.stopAccessingSecurityScopedResource() } }
                try FileService.copy([u], to: dest)
            }
        }
    }

    private func run(_ success: String, _ work: @escaping @Sendable () throws -> Void) {
        isWorking = true
        Task {
            do {
                try await Task.detached(priority: .userInitiated) { try work() }.value
                toasts.success(success)
            } catch {
                toasts.error(error)
            }
            isWorking = false
            reload()
            if isSearching { await runSearch() }
        }
    }
}

struct FileRow: View {
    let item: FileItem
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.title3)
                .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1).truncationMode(.middle)
                Text(subtitle ?? item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
