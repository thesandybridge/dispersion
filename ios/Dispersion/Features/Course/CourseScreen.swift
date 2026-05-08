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
    @State private var showHistory = false
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
        .fullScreenCover(isPresented: $showHistory) {
            RoundHistoryView(
                onBack: { showHistory = false },
                onSelectRound: { id in
                    showHistory = false
                    coursePath.append(id)
                }
            )
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
                    VStack(spacing: 6) {
                        ForEach(courses) { course in
                            courseRow(course)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Round history link
                Button { showHistory = true; Haptics.light() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                        Text("Round History")
                            .font(DispersionType.ui(14, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(ThemedCardFill(cornerRadius: 12))
                    .foregroundStyle(DesignTokens.foreground)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 12)

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

    private func courseRow(_ course: Course) -> some View {
        Button { selectedCourseId = course.id; Haptics.light() } label: {
            HStack(spacing: 12) {
                // Course icon
                Image(systemName: "flag.2.crossed")
                    .font(.system(size: 16))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(accent.opacity(0.15)))

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

                // Quick actions
                Button { buildingCourse = course; Haptics.light() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.mutedForeground)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Button { shareCourse(course); Haptics.light() } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.mutedForeground)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ThemedCardFill(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                try? CoursesRepo(context: modelContext).deleteCourse(id: course.id)
                Haptics.medium()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Round row



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

}
