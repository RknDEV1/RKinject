import SwiftUI

struct HomeView: View {
    @Binding var selection: AppTab
    @Environment(PackageManager.self) private var pm
    @Environment(SourcesStore.self) private var sources
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    stats
                    if !pm.updates.isEmpty { updatesBanner }
                    quickActions
                    activity
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Raki")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .refreshable { await pm.loadCatalog() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("home.subtitle")
                .font(.title3.weight(.semibold))
            Text("home.tagline")
                .font(.subheadline)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.6), .teal],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(pm.installed.count)", titleKey: "home.installed", symbol: "square.stack.3d.up.fill", tint: .indigo)
            StatCard(value: "\(pm.updates.count)", titleKey: "home.updates", symbol: "arrow.triangle.2.circlepath", tint: .orange)
            StatCard(value: "\(sources.builtin.count + sources.custom.count)", titleKey: "home.sources", symbol: "folder.fill", tint: .teal)
        }
    }

    private var updatesBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill").font(.title2).foregroundStyle(.orange)
            Text(L("home.updates_banner", pm.updates.count)).font(.subheadline.weight(.medium))
            Spacer()
            Button("home.update_all") { pm.updateAll() }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(.orange)
        }
        .card()
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("home.quick").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                QuickAction(titleKey: "home.browse", symbol: "folder.fill", tint: .teal) { selection = .sources }
                QuickAction(titleKey: "home.discover", symbol: "sparkles", tint: .indigo) { selection = .discover }
                QuickAction(titleKey: "home.library", symbol: "square.stack.3d.up.fill", tint: .orange) { selection = .installed }
                QuickAction(titleKey: "home.check_updates", symbol: "arrow.clockwise", tint: .pink) {
                    Task { await pm.loadCatalog() }
                }
            }
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("home.recent").font(.headline)
            VStack(alignment: .leading, spacing: 0) {
                if pm.activity.isEmpty {
                    Text("home.no_activity").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(pm.activity.prefix(6).enumerated()), id: \.element.id) { idx, entry in
                        if idx > 0 { Divider().padding(.vertical, 10) }
                        HStack(alignment: .firstTextBaseline) {
                            Text(entry.text).font(.subheadline)
                            Spacer(minLength: 8)
                            Text(entry.date, style: .relative).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }
}

private struct StatCard: View {
    let value: String
    let titleKey: LocalizedStringKey
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).font(.title2.bold())
            Text(titleKey).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

private struct QuickAction: View {
    let titleKey: LocalizedStringKey
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(titleKey).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .card(padding: 12)
        }
        .buttonStyle(.plain)
    }
}
