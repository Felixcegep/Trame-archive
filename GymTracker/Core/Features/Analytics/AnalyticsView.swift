import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 72))
                .foregroundStyle(WorkoutPalette.secondary)
                .padding(.bottom, Spacing.s)
                
            VStack(spacing: Spacing.md) {
                Text("Analytics Coming Soon")
                    .font(AppFont.titleMedium)
                    .foregroundStyle(WorkoutPalette.text)
                
                Text("Insights and progress tracking metrics will appear here as you log more workouts.")
                    .font(AppFont.subheadline)
                    .foregroundStyle(WorkoutPalette.subduedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkoutPalette.background)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
    }
}
