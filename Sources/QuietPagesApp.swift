import SwiftUI

@main
struct QuietPagesApp: App {
    init() { _ = OfflineFontLibrary.shared }
    @StateObject private var library = NotebookLibrary()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .preferredColorScheme(.light)
        }
    }
}
