import Foundation

/// How the eleven set types are presented for selection.
///
/// The list is a genuine expert vocabulary, but showing all eleven at once
/// turns a routine mid-set action into a scanning problem. Grouping does not
/// remove anything — every type stays one interaction away — it just stops the
/// four types most people use from competing with the seven they rarely touch.
///
/// The grouping is presentation only. Nothing persisted knows about it, so a
/// regrouping is never a migration.
enum SetTypeGroup: String, CaseIterable, Hashable {
    /// What a normal session is built from.
    case common
    /// Deliberate intensity techniques — reached for on purpose, not by default.
    case special
    /// Testing, structure, and recovery roles that most sessions never use.
    case more

    var title: String {
        switch self {
        case .common: String(localized: "Common")
        case .special: String(localized: "Special")
        case .more: String(localized: "More")
        }
    }

    var members: [SetType] {
        switch self {
        case .common: [.normal, .warmup, .topSet, .backoff]
        case .special: [.amrap, .failure, .technique]
        case .more: [.test, .dailyMaximum, .recovery]
        }
    }
}

extension SetType {
    /// Written as a switch rather than by searching `SetTypeGroup.members` so
    /// the compiler refuses a new set type that nobody has filed into a group.
    var group: SetTypeGroup {
        switch self {
        case .normal, .warmup, .topSet, .backoff: .common
        case .amrap, .failure, .technique: .special
        case .dropSet, .test, .dailyMaximum, .recovery: .more
        }
    }
}

/// Remembers the set types a lifter actually reaches for, so a role buried
/// under "More" surfaces after they have used it.
///
/// Deliberately pure string functions over the stored value: the views own the
/// `@AppStorage`, and the ordering rules stay testable without touching
/// `UserDefaults`.
enum RecentSetTypes {
    /// Three is what fits one row of chips at default text size. A longer
    /// memory would push the groups it is meant to shortcut off the screen.
    static let limit = 3

    private static let separator: Character = ","

    /// Most recently used first. Unknown raw values — a type removed in a later
    /// build — are dropped rather than crashing or rendering blank.
    static func decode(_ raw: String) -> [SetType] {
        raw.split(separator: separator)
            .compactMap { SetType(rawValue: String($0)) }
            .filter { isRemembered($0) }
            .reduce(into: [SetType]()) { result, type in
                guard result.contains(type) == false else { return }
                result.append(type)
            }
            .prefix(limit)
            .map { $0 }
    }

    static func encode(_ types: [SetType]) -> String {
        types.map(\.rawValue).joined(separator: String(separator))
    }

    /// Returns the stored value with `type` moved to the front.
    static func recording(_ type: SetType, into raw: String) -> String {
        guard isRemembered(type) else { return raw }
        let updated = [type] + decode(raw).filter { $0 != type }
        return encode(Array(updated.prefix(limit)))
    }

    /// Common types are always on screen already, so remembering them would
    /// spend the shortcut row on options that need no shortcut.
    private static func isRemembered(_ type: SetType) -> Bool {
        type != .dropSet && type.group != .common
    }
}
