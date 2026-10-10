import SwiftUI

struct DiscoverView: View {
    @Environment(PackageManager.self) private var pm
    @State private var query = ""
    @State private var kind: PackageKind?

    private var filtered: [CatalogPackage] {
        pm.catalog.filter { p in
            (kind == nil || p.kind == kind)
            && (query.isEmpty
                || p.name.localizedCaseInsensitiveContains(query)
                || p.summary.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    chips
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if let err = pm.catalogError {
                    Section {
                        Label {
                            Text(L("discover.catalog_error", err)).font(.subheadline)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                    }
                }
                Section {
                    if filtered.isEmpty {
                        if pm.isLoadingCatalog {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else {
                            Text("discover.empty").foregroundStyle(.secondary)
                        }
                    }
                    ForEach(filtered) { pkg in
                        NavigationLink(value: pkg) { PackageRow(pkg: pkg) }
                    }
                }
            }
            .navigationTitle("discover.title")
            .navigationDestination(for: CatalogPackage.self) { PackageDetailView(pkg: $0) }
            .searchable(text: $query, prompt: Text("discover.search"))
            .refreshable { await pm.loadCatalog() }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(titleKey: "discover.all", symbol: "square.grid.2x2.fill", tint: .accentColor, selected: kind == nil) { kind = nil }
                ForEach(PackageKind.allCases) { k in
                    Chip(titleKey: k.titleKey, symbol: k.symbol, tint: k.tint, selected: kind == k) { kind = k }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

private struct Chip: View {
    let titleKey: String
    let symbol: String
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(LocalizedStringKey(titleKey), systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? tint : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
