// Course tab: search/import courses, play holes, track shots.

import MapKit
import SwiftData
import SwiftUI

public struct CourseScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    @Query(sort: \CourseModel.name) private var courseModels: [CourseModel]

    @State private var selectedCourseId: String?
    @State private var searchOpen = false
    @State private var dial = DialStore.shared

    public init() {}

    private var courses: [Course] { courseModels.map { $0.toValue() } }

    public var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            if let id = selectedCourseId, courses.contains(where: { $0.id == id }) {
                CoursePlayView(courseId: id, onBack: { selectedCourseId = nil; Haptics.light() })
            } else {
                courseList
            }
        }
        .preferredColorScheme(.dark)
        .dispersionSheet(isPresented: $searchOpen, detents: [.large]) {
            CourseSearchSheet { course in
                selectedCourseId = course.id
                searchOpen = false
            }
        }
        .onAppear {
            dial.setActions([
                DialAction(id: "search", label: "Find course", systemImage: "magnifyingglass", tone: .primary) {
                    searchOpen = true
                }
            ])
        }
    }

    private var courseList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your courses").eyebrow()
                    Text("Course Map")
                        .font(DispersionType.display(36, weight: .regular))
                        .tracking(-0.7)
                        .foregroundStyle(DesignTokens.foreground)
                }
                .padding(.top, 16)

                if courses.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Text("No courses yet")
                            .font(DispersionType.display(24, weight: .regular))
                            .foregroundStyle(DesignTokens.foreground)
                        Text("Search for a course to import hole data from OpenStreetMap.")
                            .font(DispersionType.ui(14))
                            .foregroundStyle(DesignTokens.mutedForeground)
                            .multilineTextAlignment(.center)
                        Button { searchOpen = true } label: {
                            Text("Find a course")
                        }
                        .buttonStyle(.dispersion(.primary))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(courses) { course in
                        Button { selectedCourseId = course.id; Haptics.light() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(accent)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(accent.opacity(0.15)))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(course.name)
                                        .font(DispersionType.ui(16, weight: .medium))
                                        .foregroundStyle(DesignTokens.foreground)
                                    Text("\(course.holeCount) holes")
                                        .font(DispersionType.mono(11))
                                        .foregroundStyle(DesignTokens.mutedForeground)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
                            }
                            .padding(14)
                            .background(ThemedCardFill(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 100)
        }
    }
}
