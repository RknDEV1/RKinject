import SwiftUI

@main
struct RakiApp: App {
    @State private var packages = PackageManager()
    @State private var sources = SourcesStore()
    @State private var clipboard = FileClipboard()
    @State private var toasts = ToastCenter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(packages)
                .environment(sources)
                .environment(clipboard)
                .environment(toasts)
                .task { await packages.loadCatalog() }
        }
    }
}

enum AppTab: Hashable { case home, sources, discover, installed }

struct RootView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("tab.home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(selection: $selection)
            }
            Tab("tab.sources", systemImage: "folder.fill", value: AppTab.sources) {
                SourcesView()
            }
            Tab("tab.discover", systemImage: "sparkles", value: AppTab.discover) {
                DiscoverView()
            }
            Tab("tab.installed", systemImage: "square.stack.3d.up.fill", value: AppTab.installed) {
                InstalledView()
            }
        }
        .overlay(alignment: .top) { ToastHost() }
    }
}
