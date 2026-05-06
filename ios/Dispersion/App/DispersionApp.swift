import SwiftData
import SwiftUI

@main
struct DispersionApp: App {
    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: ClubModel.self, SessionModel.self, ShotModel.self, FaceStrikeModel.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootShell()
        }
        .modelContainer(modelContainer)
    }
}
