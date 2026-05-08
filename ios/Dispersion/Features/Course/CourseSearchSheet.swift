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
    @State private var error: String?
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
            HStack {
                ProgressView().scaleEffect(0.7)
                Text("Searching...").font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
        }

        if let error {
            Text(error)
                .font(DispersionType.ui(12))
                .foregroundStyle(DesignTokens.destructive)
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
        searching = true
        error = nil
        Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "\(query) golf course"
                if let loc = location.lastCoord {
                    request.region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng),
                        latitudinalMeters: 100_000, longitudinalMeters: 100_000
                    )
                }
                let response = try await MKLocalSearch(request: request).start()
                results = response.mapItems
                searching = false
            } catch {
                self.error = error.localizedDescription
                searching = false
            }
        }
    }

    private func searchNearby(coord: Coord) {
        searching = true
        error = nil
        Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "golf course"
                request.region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng),
                    latitudinalMeters: 30_000, longitudinalMeters: 30_000
                )
                let response = try await MKLocalSearch(request: request).start()
                results = response.mapItems
                searching = false
            } catch {
                self.error = error.localizedDescription
                searching = false
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
