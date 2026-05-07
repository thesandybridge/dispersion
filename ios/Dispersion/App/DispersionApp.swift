import SwiftData
import SwiftUI

@main
struct DispersionApp: App {
    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for:
                ClubModel.self, SessionModel.self, ShotModel.self, FaceStrikeModel.self,
                CourseModel.self, PolygonModel.self, CourseShotModel.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

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
        }
        .modelContainer(modelContainer)
    }
}
