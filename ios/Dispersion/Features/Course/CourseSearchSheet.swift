// Course search using Apple Maps MKLocalSearch. Creates a local Course
// record and default HoleInfo entries, then hands off to the map builder.

import MapKit
import SwiftData
import SwiftUI

struct CourseSearchSheet: View {
    @Environment(\.modelContext) private var modelContext
    var onImport: (Course) -> Void
    var onBuild: ((Course) -> Void)?

    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var hasSearched = false
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?
    @StateObject private var location = LocationCapture()

    var body: some View {
        DSheetHeader(eyebrow: "Course", title: "Add a course")

        HStack(spacing: 8) {
            TextField("Search golf courses", text: $searchText)
                .font(DispersionType.ui(14))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DesignTokens.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(DesignTokens.border, lineWidth: 1)
                        )
                )
                .onSubmit { search() }

            Button { search() } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.dispersion(.solid, size: .icon))
            .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
        }

        if let loc = location.lastCoord, results.isEmpty && searchText.isEmpty {
            Button {
                searchNearby(coord: loc)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill").font(.system(size: 11))
                    Text("Search nearby")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.ghost))
        }

        if searching {
            HStack(spacing: 10) {
                ProgressView().scaleEffect(0.7)
                Text("Searching...").font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
                Spacer()
                Button("Cancel") { cancelSearch() }
                    .font(DispersionType.mono(11, weight: .medium))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
        }

        if let error {
            DInlineError(error)
        }

        if !searching && hasSearched && results.isEmpty && error == nil {
            VStack(spacing: 8) {
                Spacer().frame(height: 12)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
                Text("No courses found")
                    .font(DispersionType.ui(14, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                Text("Try a different name, or create one manually below.")
                    .font(DispersionType.ui(12))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 4)
            }
            .frame(maxWidth: .infinity)
        }

        ScrollView {
            VStack(spacing: 6) {
                ForEach(results, id: \.self) { item in
                    courseRow(item)
                }
            }
        }

        // Manual creation
        VStack(spacing: 8) {
            DSeparator()
            Button {
                createManual()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle").font(.system(size: 12))
                    Text("Create manually")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.ghost))
        }
    }

    private func courseRow(_ item: MKMapItem) -> some View {
        Button {
            importCourse(item)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Unknown Course")
                        .font(DispersionType.ui(14, weight: .medium))
                        .lineLimit(1)
                    if let address = item.placemark.title {
                        Text(address)
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.mutedForeground)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignTokens.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(DesignTokens.border, lineWidth: 1)
                    )
            )
            .foregroundStyle(DesignTokens.foreground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search

    private func search() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        runSearch(query: "\(query) golf course", region: regionAroundUser(radiusMeters: 100_000))
    }

    private func searchNearby(coord: Coord) {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng),
            latitudinalMeters: 30_000, longitudinalMeters: 30_000
        )
        runSearch(query: "golf course", region: region)
    }

    private func regionAroundUser(radiusMeters: Double) -> MKCoordinateRegion? {
        guard let loc = location.lastCoord else { return nil }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng),
            latitudinalMeters: radiusMeters, longitudinalMeters: radiusMeters
        )
    }

    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        searching = false
    }

    private func runSearch(query: String, region: MKCoordinateRegion?) {
        searchTask?.cancel()
        searching = true
        error = nil
        results = []
        hasSearched = false
        searchTask = Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            if let region { request.region = region }
            let search = MKLocalSearch(request: request)

            // Race the search against a 12s timeout.
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(12))
                if !Task.isCancelled { search.cancel() }
            }
            defer { timeoutTask.cancel() }

            do {
                let response = try await search.start()
                guard !Task.isCancelled else { return }
                results = response.mapItems
                searching = false
                hasSearched = true
            } catch is CancellationError {
                searching = false
            } catch {
                guard !Task.isCancelled else { return }
                let nsError = error as NSError
                if nsError.domain == MKErrorDomain && nsError.code == MKError.unknown.rawValue {
                    self.error = "Search timed out. Check your connection and try again."
                } else {
                    self.error = "Search failed. Try a different name."
                }
                searching = false
                hasSearched = true
            }
        }
    }

    // MARK: - Import

    private func importCourse(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        let course = Course(
            id: UUID().uuidString.lowercased(),
            name: item.name ?? "Golf Course",
            centerLat: coord.latitude,
            centerLng: coord.longitude
        )
        createCourseWithDefaults(course)
    }

    private func createManual() {
        let name = searchText.trimmingCharacters(in: .whitespaces)
        let course = Course(
            id: UUID().uuidString.lowercased(),
            name: name.isEmpty ? "My Course" : name,
            centerLat: location.lastCoord?.lat ?? 0,
            centerLng: location.lastCoord?.lng ?? 0
        )
        createCourseWithDefaults(course)
    }

    private func createCourseWithDefaults(_ course: Course) {
        do {
            let repo = CoursesRepo(context: modelContext)
            try repo.createCourse(course)
            // Create default HoleInfo records for 18 holes
            for h in 1...course.holeCount {
                try repo.upsertHoleInfo(HoleInfo(courseId: course.id, holeNumber: h))
            }
            Haptics.success()
            if let onBuild {
                onBuild(course)
            } else {
                onImport(course)
            }
        } catch {
            self.error = "Failed to create course: \(error.localizedDescription)"
            Haptics.error()
        }
    }
}
