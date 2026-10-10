import SwiftUI

struct PackageDetailView: View {
    let pkg: CatalogPackage
    @Environment(PackageManager.self) private var pm

    private var state: PackageState { pm.state(for: pkg) }
    private var record: InstalledRecord? { pm.record(for: pkg.id) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                infoCard
                statusCard
                actions
                if !pkg.summary.isEmpty { aboutCard }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(pkg.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 10) {
            KindIcon(kind: pkg.kind, size: 84)
            Text(pkg.name).font(.title2.bold()).multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Text(LocalizedStringKey(pkg.kind.titleKey)).font(.subheadline).foregroundStyle(.secondary)
                StatusBadge(state: state)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var infoCard: some View {
        HStack(spacing: 0) {
            info("detail.version", "v\(pkg.version)")
            Divider().frame(height: 32)
            info("detail.size", pkg.size.byteString)
            Divider().frame(height: 32)
            info("detail.author", pkg.author)
        }
        .card(padding: 14)
    }

    private func info(_ key: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(key)).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusCard: some View {
        switch state {
        case .downloading(let p):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L("status.downloading", Int(p * 100))).font(.subheadline.weight(.medium))
                    Spacer()
                }
                ProgressView(value: p)
            }
            .card()
        case .installing:
            HStack(spacing: 10) {
                ProgressView()
                Text("status.installing").font(.subheadline.weight(.medium))
                Spacer()
            }
            .card()
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("detail.error_title", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        case .updateAvailable:
            if let record {
                Label(L("detail.update_info", record.version, pkg.version), systemImage: "arrow.down.circle.fill")
                    .font(.subheadline).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
        case .installed:
            if let record {
                Label(L("detail.installed_info", record.version), systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
        case .notInstalled:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            switch state {
            case .notInstalled:
                bigButton("action.install", tint: .accentColor) { pm.install(pkg) }
            case .updateAvailable:
                bigButton("action.update", tint: .orange) { pm.install(pkg) }
            case .failed:
                bigButton("action.retry", tint: .red) { pm.install(pkg) }
            case .downloading, .installing, .installed:
                EmptyView()
            }
            if record != nil, !isBusy {
                NavigationLink {
                    FileBrowserView(url: Paths.packageDir(pkg.id), title: pkg.name)
                } label: {
                    Label("installed.browse_files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)

                Button(role: .destructive) { pm.remove(pkg.id) } label: {
                    Label("action.remove", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
        }
    }

    private var isBusy: Bool {
        switch state {
        case .downloading, .installing: return true
        default: return false
        }
    }

    private func bigButton(_ key: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(key)).font(.headline).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).controlSize(.large).tint(tint)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("detail.about").font(.headline)
            Text(pkg.summary).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
