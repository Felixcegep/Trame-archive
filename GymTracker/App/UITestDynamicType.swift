import SwiftUI

/// A capture-only Dynamic Type override.
///
/// Accessibility text sizes are a design contract rather than a product
/// setting, so there is no in-app control to drive and no deterministic way to
/// reach AX5 from a UI test other than naming it at launch. The override is
/// applied above `RootView` because Active Workout, mobility, and onboarding
/// are all presented as full-screen covers, and only an ancestor's environment
/// reaches every one of them.
enum UITestDynamicType {
    static let argument = "-ui-testing-dynamic-type"

    static func override(arguments: [String] = AppLaunchArguments.current) -> DynamicTypeSize? {
        guard let flag = arguments.firstIndex(of: argument),
              arguments.indices.contains(flag + 1)
        else {
            return nil
        }
        return size(named: arguments[flag + 1])
    }

    /// Named rather than indexed: a capture scene records which size it is
    /// asserting, and an unknown name is ignored instead of silently resolving
    /// to a neighbouring step.
    static func size(named name: String) -> DynamicTypeSize? {
        switch name {
        case "xSmall": .xSmall
        case "large": .large
        case "xxxLarge": .xxxLarge
        case "accessibility1": .accessibility1
        case "accessibility3": .accessibility3
        case "accessibility5": .accessibility5
        default: nil
        }
    }
}

extension View {
    @ViewBuilder
    func uiTestDynamicTypeOverride() -> some View {
        if let size = UITestDynamicType.override() {
            dynamicTypeSize(size)
        } else {
            self
        }
    }
}
