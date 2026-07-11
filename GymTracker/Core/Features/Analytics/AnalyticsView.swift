import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Header / Intro
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("PROGRESS TRACKING")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(Color.gymText.opacity(0.58))
                    
                    Text("Nice work this week.")
                        .font(AppFont.displayMedium)
                        .foregroundStyle(Color.gymText)
                    
                    Text("Your performance metrics are compiled below.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymText.opacity(0.58))
                }
                .padding(.top, Spacing.s)
                
                // Volume Progress Card
                VStack(alignment: .leading, spacing: Spacing.m) {
                    HStack {
                        Label("WEEKLY FREQUENCY", systemImage: "chart.bar.fill")
                            .font(AppFont.captionBold)
                            .tracking(0.8)
                            .foregroundStyle(Color.gymPrimary)
                        Spacer()
                    }
                    
                    Text("Workout Streak")
                        .font(AppFont.titleSmall)
                        .foregroundStyle(Color.gymText)
                    
                    // Simple Mock Bar Chart
                    HStack(alignment: .bottom, spacing: Spacing.m) {
                        ForEach(mockWeeklyFrequency) { day in
                            VStack(spacing: Spacing.s) {
                                ZStack(alignment: .bottom) {
                                    Capsule()
                                        .fill(Color.gymPrimary.opacity(0.08))
                                        .frame(height: 100)
                                    
                                    Capsule()
                                        .fill(day.isActive ? Color.gymPrimary : Color.clear)
                                        .frame(height: day.isActive ? day.height : 0)
                                }
                                .frame(width: 14)
                                
                                Text(day.label)
                                    .font(AppFont.captionBold)
                                    .foregroundStyle(day.isActive ? Color.gymPrimary : Color.gymText.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.l)
                .background(Color.gymCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.gymText.opacity(0.08), lineWidth: 1.5)
                }
                
                // Stats Summary Row
                HStack(spacing: Spacing.m) {
                    metricCard(title: "Workouts", value: "12", icon: "figure.strengthtraining.traditional", color: Color.gymSecondary)
                    metricCard(title: "Active Time", value: "8.4h", icon: "clock.fill", color: Color.gymAccent)
                }
                
                // Muscle Group Breakdown
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Label("MUSCLE DISTRIBUTION", systemImage: "dumbbell.fill")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(Color.gymSecondary)
                    
                    Text("Focus Balance")
                        .font(AppFont.titleSmall)
                        .foregroundStyle(Color.gymText)
                    
                    VStack(spacing: Spacing.s) {
                        muscleProgressRow(name: "Push", percentage: 0.45, color: Color.gymPrimary)
                        muscleProgressRow(name: "Pull", percentage: 0.35, color: Color.gymSecondary)
                        muscleProgressRow(name: "Legs", percentage: 0.20, color: Color.gymAccent)
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.l)
                .background(Color.gymCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.gymText.opacity(0.08), lineWidth: 1.5)
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Image(systemName: icon)
                    .font(AppFont.headline)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(AppFont.displayLarge)
                .foregroundStyle(Color.gymText)
            
            Text(title)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymText.opacity(0.58))
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gymText.opacity(0.08), lineWidth: 1.5)
        }
    }
    
    private func muscleProgressRow(name: String, percentage: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(name)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                Spacer()
                Text(String(format: "%.0f%%", percentage * 100))
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymText.opacity(0.58))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.08))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * percentage, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    private struct WeeklyFrequencyDay: Identifiable {
        let id = UUID()
        let label: String
        let height: CGFloat
        let isActive: Bool
    }
    
    private var mockWeeklyFrequency: [WeeklyFrequencyDay] {
        [
            WeeklyFrequencyDay(label: "M", height: 80, isActive: true),
            WeeklyFrequencyDay(label: "T", height: 0, isActive: false),
            WeeklyFrequencyDay(label: "W", height: 60, isActive: true),
            WeeklyFrequencyDay(label: "T", height: 90, isActive: true),
            WeeklyFrequencyDay(label: "F", height: 0, isActive: false),
            WeeklyFrequencyDay(label: "S", height: 50, isActive: true),
            WeeklyFrequencyDay(label: "S", height: 0, isActive: false)
        ]
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
    }
}
