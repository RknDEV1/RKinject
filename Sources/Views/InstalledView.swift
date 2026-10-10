import SwiftUI

struct InstalledView: View {
    @Environment(PackageManager.self) private var pm

    private var withUpdates: [InstalledRecord] {
        pm.installed.filter { r in pm.state(for: pm.package(for: r)) == .updateAvailable }
    }

    private var others: [InstalledRecord] {
        pm.installed.filter { r in pm.state(for: pm.package(for: r)) != .updateAvailable }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pm.installed.isEmpty {
                    ContentUnavailableView("installed.empty", systemImage: "square.stack.3d.up",
                                           description: Text("installed.empty_hint"))
                } else {
                    List {
                        if !withUpdates.isEmpty {
                            Section {
                                ForEach(withUpdates) { row($0) }
                            } header: {
                                Text("installed.updates_section")
                            } footer: {
                                Button("home.update_all") { pm.updateAll() }
                                    .buttonStyle(.borderedProminent).tint(.orange).controlSize(.small)
                                    .padding(.top, 6)
                            }
                        }
                        Section("installed.all_section") {
                            ForEach(others) { row($0) }
                        }
                    }
                }
            }
            .navigationTitle("installed.title")
            .navigationDestination(for: CatalogPackage.self) { PackageDetailView(pkg: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await pm.loadCatalog() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(pm.isLoadingCatalog)
                }
            }
            .refreshable { await pm.loadCatalog() }
        }
    }

    private func row(_ r: InstalledRecord) -> some View {
        let pkg = pm.package(for: r)
        let state = pm.state(for: pkg)
        return NavigationLink(value: pkg) {
            HStack(spacing: 12) {
                KindIcon(kind: r.kind, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.name).font(.headline).lineLimit(1)
                    Text("v\(r.version) · \(r.size.byteString)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                StatusBadge(state: state == .notInstalled ? .installed : state)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { pm.remove(r.id) } label: { Label("action.remove", systemImage: "trash") }
        }
    }
}
