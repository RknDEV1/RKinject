import Foundation

enum Paths {
    private static func ensure(_ url: URL) -> URL {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var library: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    }

    static var imported: URL {
        ensure(documents.appendingPathComponent("Imported", isDirectory: true))
    }

    static var appSupport: URL {
        ensure(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Raki", isDirectory: true))
    }

    static var installedRoot: URL {
        ensure(appSupport.appendingPathComponent("Installed", isDirectory: true))
    }

    static var stateFile: URL {
        appSupport.appendingPathComponent("state.json")
    }

    static func packageDir(_ id: String) -> URL {
        installedRoot.appendingPathComponent(id, isDirectory: true)
    }
}
