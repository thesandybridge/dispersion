// Course tab: add/build courses, play holes, track shots.

import MapKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

public struct CourseScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    @Query(sort: \CourseModel.name) private var courseModels: [CourseModel]

    @State private var selectedCourseId: String?
    @State private var coursePath = NavigationPath()
    @State private var searchOpen = false
    @State private var buildingCourse: Course?
    @State private var importerOpen = false
    @State private var importStatus: String?
    @State private var dial = DialStore.shared

    public init() {}

    private var courses: [Course] { courseModels.map { $0.toValue() } }

    public var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            if let id = selectedCourseId, courses.contains(where: { $0.id == id }) {
                CoursePlayView(courseId: id, onBack: { selectedCourseId = nil; Haptics.light() })
            } else {
                NavigationStack(path: $coursePath) {
                    courseList
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: String.self) { roundId in
                            let session = (try? SessionsRepo(context: modelContext).get(id: roundId))
                            RoundSummaryView(
                                sessionId: roundId,
                                courseName: session?.label ?? "Round",
                                onBack: { coursePath.removeLast() }
                            )
                            .toolbar(.hidden, for: .navigationBar)
                            .enableInteractivePop()
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
        .dispersionSheet(isPresented: $searchOpen, detents: [.large]) {
            CourseSearchSheet(
                onImport: { course in
                    selectedCourseId = course.id
                    searchOpen = false
                },
                onBuild: { course in
                    searchOpen = false
                    buildingCourse = course
                }
            )
        }
        .fullScreenCover(item: $buildingCourse) { course in
            MapBuilderView(courseId: course.id, course: course) {
                buildingCourse = nil
            }
        }
        .fileImporter(isPresented: $importerOpen, allowedContentTypes: [.json]) { result in
            importCourse(result)
        }
        .onAppear {
            coursePath = NavigationPath()
            dial.setActions([
                DialAction(id: "search", label: "Add course", systemImage: "plus", tone: .primary) {
                    searchOpen = true
                }
            ])
        }
    }

    private var courseList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    Text("Course")
                        .font(DispersionType.display(32, weight: .regular))
                        .tracking(-0.7)
                        .foregroundStyle(DesignTokens.foreground)
                    Spacer()
                    HStack(spacing: 8) {
                        Button { importerOpen = true } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 13, weight: .medium))
                                .padding(10)
                                .background(Circle().fill(DesignTokens.surface))
                                .foregroundStyle(DesignTokens.foreground)
                        }
                        .buttonStyle(.plain)

                        Button { searchOpen = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(10)
                                .background(Circle().fill(accent))
                                .foregroundStyle(DesignTokens.primaryForeground)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if let status = importStatus {
                    Text(status)
                        .font(DispersionType.ui(12))
                        .foregroundStyle(DesignTokens.primary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                if courses.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(courses) { course in
                            courseCard(course)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if !roundSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Round history").eyebrow()
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        ForEach(roundSessions, id: \.id) { session in
                            roundRow(session)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 100)
            }
        }
        .background(DesignTokens.background)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Text("No courses yet")
                .font(DispersionType.display(24, weight: .regular))
                .foregroundStyle(DesignTokens.foreground)
            Text("Search for a course, then build your course map.")
                .font(DispersionType.ui(14))
                .foregroundStyle(DesignTokens.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { searchOpen = true } label: {
                Text("Add a course")
            }
            .buttonStyle(.dispersion(.primary))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Course card

    private func courseCard(_ course: Course) -> some View {
        Button { selectedCourseId = course.id; Haptics.light() } label: {
            VStack(spacing: 0) {
                // Map preview
                Map(initialPosition: .camera(MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: course.centerLat, longitude: course.centerLng),
                    distance: 1500
                ))) {
                    let polys = (try? CoursesRepo(context: modelContext).polygons(courseId: course.id)) ?? []
                    ForEach(polys.filter { $0.coordinates.count >= 3 }, id: \.id) { polygon in
                        MapPolygon(coordinates: polygon.coordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        })
                        .foregroundStyle(mapFill(polygon.surface))
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                    }
                }
                .mapStyle(.imagery)
                .frame(height: 120)
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Info
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name)
                            .font(DispersionType.ui(15, weight: .medium))
                            .foregroundStyle(DesignTokens.foreground)
                            .lineLimit(1)
                        Text("\(course.holeCount) holes")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(ThemedCardFill(cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { selectedCourseId = course.id } label: {
                Label("Play", systemImage: "flag.fill")
            }
            Button { buildingCourse = course } label: {
                Label("Edit map", systemImage: "pencil")
            }
            Button { shareCourse(course) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                try? CoursesRepo(context: modelContext).deleteCourse(id: course.id)
                Haptics.medium()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Round row

    private func roundRow(_ session: Session) -> some View {
        Button { coursePath.append(session.id); Haptics.light() } label: {
            HStack(spacing: 12) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.label)
                        .font(DispersionType.ui(14, weight: .medium))
                        .foregroundStyle(DesignTokens.foreground)
                    Text(session.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
            }
            .padding(12)
            .background(ThemedCardFill(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share / Import

    private func shareCourse(_ course: Course) {
        let repo = CoursesRepo(context: modelContext)
        let holeInfos = (try? repo.holeInfos(courseId: course.id)) ?? []
        let polygons = (try? repo.polygons(courseId: course.id)) ?? []
        let data = CourseExport.build(course: course, holeInfos: holeInfos, polygons: polygons)

        let fileName = course.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
            .appending(".dispersion.json")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)

        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func importCourse(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let e):
            importStatus = "Import failed: \(e.localizedDescription)"
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                importStatus = "Cannot access file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let parsed = try CourseExport.parse(data)
                let repo = CoursesRepo(context: modelContext)
                try repo.createCourse(parsed.course)
                for info in parsed.holeInfos { try repo.upsertHoleInfo(info) }
                try repo.insertPolygons(parsed.polygons)
                importStatus = "Imported \(parsed.course.name)"
                Haptics.success()
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    importStatus = nil
                }
            } catch {
                importStatus = "Import failed: \(error.localizedDescription)"
                Haptics.error()
            }
        }
    }

    private func mapFill(_ surface: SurfaceType) -> Color {
        switch surface {
        case .green:   return hex("#A8C97F").opacity(0.6)
        case .fairway: return hex("#C4D49A").opacity(0.5)
        case .bunker:  return hex("#E8DCC0").opacity(0.5)
        case .water:   return hex("#7EA5C4").opacity(0.5)
        case .tee:     return hex("#B8C880").opacity(0.5)
        case .rough:   return hex("#8FA66B").opacity(0.4)
        }
    }

    private var roundSessions: [Session] {
        ((try? SessionsRepo(context: modelContext).list()) ?? [])
            .filter { $0.kind == .round }
    }
}
