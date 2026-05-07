// Search for golf courses via GolfBert API. Import course with full
// hole data, tee boxes, pars, and polygon outlines.

import SwiftData
import SwiftUI

struct CourseSearchSheet: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var location = LocationCapture()

    @State private var searchText = ""
    @State private var results: [GolfBertClient.GBCourse] = []
    @State private var loading = false
    @State private var importing: Int?
    @State private var error: String?
    @State private var importedCourse: Course?

    var onImport: (Course) -> Void

    var body: some View {
        DSheetHeader(eyebrow: "Find a course", title: "Course Search")

        Button { searchNearby() } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill").font(.system(size: 13))
                Text(loading && importing == nil ? "Searching..." : "Search nearby")
                    .font(DispersionType.ui(14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.dispersion(.primary))
        .disabled(loading)

        HStack(spacing: 8) {
            TextField("Course name", text: $searchText)
                .font(DispersionType.ui(15))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DesignTokens.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(DesignTokens.border, lineWidth: 1))
                )
                .onSubmit { searchByName() }
        }

        if let error {
            Text(error)
                .font(DispersionType.ui(12))
                .foregroundStyle(DesignTokens.destructive)
        }

        if let course = importedCourse {
            Button { onImport(course) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(DesignTokens.primary)
                    Text("Open \(course.name)")
                        .font(DispersionType.ui(14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.primary))
        }

        ForEach(results) { course in
            Button { importCourse(course) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name)
                            .font(DispersionType.ui(14, weight: .medium))
                        Text(course.address?.displayString ?? "")
                            .font(DispersionType.mono(11))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    Spacer()
                    if importing == course.id {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Text("Import")
                            .font(DispersionType.mono(10, weight: .medium))
                            .foregroundStyle(DesignTokens.primary)
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .disabled(importing != nil)
        }
    }

    // MARK: - Actions

    private func searchNearby() {
        loading = true; error = nil; results = []
        Task {
            do {
                if !location.isAuthorized {
                    location.requestPermission()
                    try await Task.sleep(for: .seconds(1))
                }
                let coord = try await location.capture()
                results = try await GolfBertClient.searchCourses(lat: coord.lat, lng: coord.lng)
                if results.isEmpty { error = "No courses found nearby" }
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func searchByName() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        loading = true; error = nil; results = []
        Task {
            do {
                results = try await GolfBertClient.searchCourses(name: q)
                if results.isEmpty { error = "No courses found for '\(q)'" }
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func importCourse(_ gbCourse: GolfBertClient.GBCourse) {
        importing = gbCourse.id; error = nil
        Task {
            do {
                // Fetch holes, scorecard, and polygons
                let holes = try await GolfBertClient.getHoles(courseId: gbCourse.id)
                let scorecard = try await GolfBertClient.getScorecard(courseId: gbCourse.id)

                let courseId = UUID().uuidString.lowercased()
                let course = Course(
                    id: courseId,
                    name: gbCourse.name,
                    centerLat: gbCourse.coordinates?.lat ?? 0,
                    centerLng: gbCourse.coordinates?.long ?? 0,
                    holeCount: holes.count
                )

                let repo = CoursesRepo(context: modelContext)
                try repo.createCourse(course)

                // Store hole data as polygons (tee/flag vectors)
                var polygons: [CoursePolygon] = []
                for hole in holes {
                    // Flag as green marker
                    if let flag = hole.flagPosition {
                        polygons.append(CoursePolygon(
                            id: UUID().uuidString.lowercased(),
                            courseId: courseId, holeNumber: hole.number,
                            surface: .green,
                            coordinates: [flag]
                        ))
                    }
                    // Tee boxes
                    for vec in hole.vectors ?? [] where vec.type != "Flag" {
                        polygons.append(CoursePolygon(
                            id: UUID().uuidString.lowercased(),
                            courseId: courseId, holeNumber: hole.number,
                            surface: .tee,
                            coordinates: [Coord(lat: vec.lat, lng: vec.long)]
                        ))
                    }
                }

                // Fetch polygons for each hole (fairway/bunker outlines)
                for hole in holes {
                    if let holePolygons = try? await GolfBertClient.getPolygons(holeId: hole.id) {
                        for gp in holePolygons {
                            guard let surface = gp.surface else { continue }
                            let coords = gp.polygon.map { Coord(lat: $0.lat, lng: $0.long) }
                            guard coords.count >= 3 else { continue }
                            polygons.append(CoursePolygon(
                                id: UUID().uuidString.lowercased(),
                                courseId: courseId, holeNumber: hole.number,
                                surface: surface, coordinates: coords
                            ))
                        }
                    }
                }

                try repo.insertPolygons(polygons)

                // Store scorecard data in UserDefaults keyed by courseId
                let scorecardData = try JSONEncoder().encode(scorecard.holeteeboxes)
                UserDefaults.standard.set(scorecardData, forKey: "scorecard.\(courseId)")

                // Store hole vectors for quick access
                let holesData = try JSONEncoder().encode(holes)
                UserDefaults.standard.set(holesData, forKey: "holes.\(courseId)")

                importedCourse = course
                Haptics.success()
            } catch {
                self.error = error.localizedDescription
            }
            importing = nil
        }
    }
}

