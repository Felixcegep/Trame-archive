import SwiftUI

#if !GYMTRACKER_EXTENSION

struct ProgramDefinitionRuleEditor: View {
    @Binding var rule: ProgressionRuleDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Picker("Metric", selection: $rule.metric) {
                ForEach(ProgressionMetric.allCases, id: \.self) { metric in
                    Text(metric.rawValue.localizedCapitalized).tag(metric)
                }
            }

            RuleTriggerEditor(trigger: $rule.trigger)

            RuleActionEditor(successAction: $rule.successAction, failureAction: $rule.failureAction)

            RuleFormulaEditor(formula: $rule.formula)

            Picker("Cadence", selection: $rule.cadence) {
                ForEach(ProgressionCadence.allCases, id: \.self) { cadence in
                    Text(cadence.rawValue.localizedCapitalized).tag(cadence)
                }
            }
            Picker("Scope", selection: $rule.scope) {
                ForEach(ProgressionScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue.localizedCapitalized).tag(scope)
                }
            }
            Picker("Apply", selection: $rule.applicationMode) {
                ForEach(ProgressionApplicationMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.localizedCapitalized).tag(mode)
                }
            }
            Toggle("Enabled", isOn: $rule.isEnabled)
        }
        .padding(.vertical, Spacing.xxs)
    }
}

#endif
