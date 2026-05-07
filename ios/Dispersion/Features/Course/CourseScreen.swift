// Course tab: search/import courses, play holes, track shots.

import MapKit
import SwiftData
import SwiftUI

public struct CourseScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    @Query(sort: \CourseModel.name) private var courseModels: [CourseModel]

    @State private var selectedCourseId: String?
    @State private var viewingRoundId: String?
    @State private var searchOpen = false
    @State private var dial = DialStore.shared

    public init() {}

    private var courses: [Course] { courseModels.map { $0.toValue() } }

    public var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            if let roundId = viewingRoundId {
                let session = (try? SessionsRepo(context: modelContext).get(id: roundId))
                RoundSummaryView(
                    sessionId: roundId,
                    courseName: session?.label ?? "Round",
                    onBack: { viewingRoundId = nil }
                )
            } else if let id = selectedCourseId, courses.contains(where: { $0.id == id }) {
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
            viewingRoundId = nil
            dial.setActions([
                DialAction(id: "search", label: "Find course", systemImage: "magnifyingglass", tone: .primary) {
                    searchOpen = true
                }
            ])
        }
    }

    private var courseList: some View {
        List {
            Section {
                HStack(alignment: .center) {
                    Text("Course")
                        .font(DispersionType.display(32, weight: .regular))
                        .tracking(-0.7)
                        .foregroundStyle(DesignTokens.foreground)
                    Spacer()
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
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if courses.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Text("No courses yet")
                            .font(DispersionType.display(24, weight: .regular))
                            .foregroundStyle(DesignTokens.foreground)
                        Text("Search for a course to import hole data from GolfBert.")
                            .font(DispersionType.ui(14))
                            .foregroundStyle(DesignTokens.mutedForeground)
                            .multilineTextAlignment(.center)
                        Button { searchOpen = true } label: {
                            Text("Find a course")
                        }
                        .buttonStyle(.dispersion(.primary))
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(courses) { course in
                        Button { selectedCourseId = course.id; Haptics.light() } label: {
                            HStack(spacing: 12) {
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
                                    .font(.system(size: 11))
                                    .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            try? CoursesRepo(context: modelContext).deleteCourse(id: courses[i].id)
                        }
                        Haptics.medium()
                    }
                }
                .listRowBackground(ThemedCardFill(cornerRadius: 10))
                .listRowSeparator(.hidden)
            }

            Section {
                roundHistory
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.background)
    }

    private var roundSessions: [Session] {
        ((try? SessionsRepo(context: modelContext).list()) ?? [])
            .filter { $0.kind == .round }
    }

    @ViewBuilder
    private var roundHistory: some View {
        if !roundSessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Round history").eyebrow()
                ForEach(roundSessions, id: \.id) { session in
                    Button { viewingRoundId = session.id; Haptics.light() } label: {
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
            }
        }
    }
}
