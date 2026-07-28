import Foundation

/// The only supported way to construct a `WhyExplanationModel`.
///
/// It exists to make three rules structural rather than conventional:
///
/// 1. **Headings come from the kind.** There is no parameter for a section
///    title, so a surface cannot rename a shared concept.
/// 2. **Order comes from the kind.** Sections are sorted on build, so the
///    order a surface happens to call `add` in is irrelevant.
/// 3. **Missing evidence cannot be silently dropped.** `noteMissingEvidence`
///    is the only way to record it and it writes into `.confidence` itself, so
///    there is no code path that knows evidence is missing and renders no
///    confidence section. That was the failure this component exists to
///    prevent: a verdict that looks certain because the gaps went unmentioned.
///
/// Omission is allowed and expected — a surface with nothing to say about the
/// plan simply never adds `.effectOnPlan`, and empty sections are dropped.
struct WhyExplanationBuilder {
    private let title: String
    private let subtitle: String?
    /// `true` for surfaces where something is actually being accepted or
    /// declined. A non-decision surface silently drops decision-only sections
    /// instead of relying on every caller to remember not to add them.
    private let isDecision: Bool

    private var bodies: [WhyExplanationSectionKind: String] = [:]
    private var items: [WhyExplanationSectionKind: [String]] = [:]

    init(title: String, subtitle: String? = nil, isDecision: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.isDecision = isDecision
    }

    /// Adds content to a section. Repeated calls for the same kind append,
    /// so a caller can contribute evidence from several sources without
    /// having to assemble one array first.
    mutating func add(
        _ kind: WhyExplanationSectionKind,
        body: String? = nil,
        items newItems: [String] = []
    ) {
        guard isDecision || !kind.requiresDecision else { return }

        if let body, !body.isEmpty {
            // Multiple bodies for one kind read as paragraphs, not as a
            // replacement — losing the earlier one would silently drop
            // evidence.
            bodies[kind] = bodies[kind].map { "\($0)\n\n\(body)" } ?? body
        }
        let filtered = newItems.filter { !$0.isEmpty }
        if !filtered.isEmpty {
            items[kind, default: []].append(contentsOf: filtered)
        }
    }

    /// Records the confidence qualifier and, when present, the evidence that
    /// was **not** available. Naming the gaps is the point; a qualifier with
    /// no gaps listed is just an adjective.
    mutating func noteMissingEvidence(
        qualifier: String,
        missing: [String] = [],
        introduction: String? = nil
    ) {
        let named = missing.filter { !$0.isEmpty }
        if named.isEmpty {
            add(.confidence, body: qualifier)
            return
        }
        let intro = introduction ?? String(
            localized: "why.confidence.missing.intro",
            defaultValue: "Not recorded for this:"
        )
        add(.confidence, body: "\(qualifier)\n\n\(intro)", items: named)
    }

    func build() -> WhyExplanationModel {
        let kinds = Set(bodies.keys).union(items.keys).sorted()
        let sections = kinds.map { kind in
            WhyExplanationModel.Section(
                kind: kind,
                items: items[kind] ?? [],
                body: bodies[kind]
            )
        }
        return WhyExplanationModel(title: title, subtitle: subtitle, sections: sections)
    }
}
