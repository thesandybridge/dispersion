import SwiftData
import SwiftUI

@main
struct DispersionApp: App {
    let modelContainer: ModelContainer
    @State private var dbFailed: Bool

    private static let allModels: [any PersistentModel.Type] = [
        ClubModel.self, SessionModel.self, ShotModel.self, FaceStrikeModel.self,
        CourseModel.self, PolygonModel.self, CourseShotModel.self, HoleInfoModel.self,
        RoundModel.self,
        PutterModel.self, PuttModel.self
    ]

    /// One-time migration flag — when the new putter schema replaced the old
    /// "putter as a Club" idea, we wipe the legacy putter Club + its Shots so
    /// they don't appear in the bag (the new Putter is the source of truth).
    private static let putterWipeKey = "putterModelWipeV1"

    init() {
        let schema = Schema(Self.allModels)
        do {
            let config = ModelConfiguration(schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            _dbFailed = State(initialValue: false)
            Self.runOneTimePutterWipe(container: modelContainer)
        } catch {
            print("⚠️ Failed to open database: \(error). Falling back to in-memory store.")
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [memConfig])
                _dbFailed = State(initialValue: true)
            } catch {
                // Truly catastrophic — even an in-memory container won't open.
                // No way to render UI without a container, so abort with a clear log.
                fatalError("Dispersion couldn't start: SwiftData refused both persistent and in-memory stores. Underlying error: \(error)")
            }
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

    /// Wipes any pre-existing ClubModel that classifies as a putter — and its
    /// associated Shot rows. Runs at most once, gated by UserDefaults. Idempotent
    /// on subsequent launches.
    @MainActor
    private static func runOneTimePutterWipe(container: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: putterWipeKey) else { return }
        let context = container.mainContext
        let clubsRepo = ClubsRepo(context: context)
        let shotsRepo = ShotsRepo(context: context)
        do {
            let clubs = try clubsRepo.list()
            for c in clubs {
                let cat = ClubCategoryRegistry.categorize(name: c.name, carryYards: c.carryYards)
                if cat == .putter {
                    try shotsRepo.deleteByClub(c.id)
                    try clubsRepo.delete(id: c.id)
                }
            }
            UserDefaults.standard.set(true, forKey: putterWipeKey)
        } catch {
            print("⚠️ Putter wipe failed: \(error). Will retry on next launch.")
        }
    }
}
