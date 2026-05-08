import SwiftData
import SwiftUI

@main
struct DispersionApp: App {
    let modelContainer: ModelContainer
    @State private var dbFailed: Bool

    private static let allModels: [any PersistentModel.Type] = [
        ClubModel.self, SessionModel.self, ShotModel.self, FaceStrikeModel.self,
        CourseModel.self, PolygonModel.self, CourseShotModel.self
    ]

    init() {
        let schema = Schema(Self.allModels)
        do {
            let config = ModelConfiguration(schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            _dbFailed = State(initialValue: false)
        } catch {
            // Fall back to in-memory so the app can launch without crashing
            print("⚠️ Failed to open database: \(error). Using in-memory store.")
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: schema, configurations: [memConfig])
            _dbFailed = State(initialValue: true)
        }
    }

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootShell()
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashScreen {
                        showSplash = false
                    }
                    .transition(.opacity)
                }
            }
            .alert("Database error", isPresented: $dbFailed) {
                Button("OK") {}
            } message: {
                Text("Could not open your saved data. The app is running with a temporary store. Try restarting — if this persists, reinstall the app.")
            }
        }
        .modelContainer(modelContainer)
    }
}
