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
                .alert("Сохранение данных", isPresented: Binding(
                    get: { library.storageError != nil },
                    set: { if !$0 { library.storageError = nil } }
                ), actions: { Button("Понятно") { library.storageError = nil } },
                message: { Text(library.storageError ?? "") })
        }
    }
}
