import Foundation

struct AppIcon {
    // Navigation & Global Action Icons
    static let home = "house.fill"
    static let folders = "folder.fill"
    static let history = "clock.arrow.circlepath"
    static let settings = "gearshape"
    static let plan = "calendar"
    static let planAdd = "calendar.badge.plus"
    static let reschedule = "calendar.badge.clock"
    static let tomorrow = "calendar.badge.plus"
    static let minimize = "chevron.down"
    static let chevronLeft = "chevron.left"
    static let chevronRight = "chevron.right"
    static let chevronUp = "chevron.up"
    static let chevronDown = "chevron.down"
    static let picker = "chevron.up.chevron.down"
    
    // Action Icons
    static let plus = "plus"
    static let minus = "minus"
    static let trash = "trash"
    static let copy = "doc.on.doc"
    static let ellipsis = "ellipsis"
    static let edit = "pencil"
    static let lock = "lock.fill"
    static let save = "arrow.down.circle.fill"
    static let filters = "line.3.horizontal.decrease.circle"
    static let play = "play.fill"
    static let pause = "pause.fill"
    static let reset = "arrow.counterclockwise"
    static let archive = "archivebox"
    static let export = "square.and.arrow.up"
    static let `import` = "square.and.arrow.down"
    static let feedback = "envelope"
    static let backspace = "delete.left"

    // Status & Feedback Icons
    static let checkmark = "checkmark"
    static let checkmarkCircle = "checkmark.circle.fill"
    static let failureCircle = "xmark.circle.fill"
    static let circle = "circle"
    static let circleFill = "circle.fill"
    /// Marks the one row a user is acting on. A silhouette rather than a tint,
    /// so "you are here" survives grayscale, Increase Contrast, and colour
    /// blindness instead of resting on an accent hue alone.
    static let currentPointer = "arrowtriangle.forward.fill"
    static let circleDashed = "circle.dashed"
    static let skip = "circle.slash"
    static let info = "info.circle"
    static let warning = "exclamationmark.triangle"
    static let warningCircle = "exclamationmark.circle"
    static let number = "number"
    static let favorite = "star"
    static let favoriteFilled = "star.fill"
    static let favoriteRemove = "star.slash"
    static let restore = "arrow.uturn.backward"
    static let remove = "xmark.circle.fill"
    
    // Specific Features
    static let workout = "dumbbell.fill"
    static let mobility = "figure.flexibility"
    // Mobility routine purpose. Reinforcement only — the purpose name always
    // accompanies these, so meaning never rests on the glyph.
    static let mobilityPurposePreparation = "figure.run"
    static let mobilityPurposeDevelopment = "figure.flexibility"
    static let mobilityPurposeCooldown = "figure.cooldown"
    /// Mobility assessment. A measuring instrument, deliberately not a gauge or
    /// a dial: an assessment records an observation, it does not rate one.
    static let mobilityAssessment = "ruler"
    static let nutrition = "fork.knife"
    static let caffeine = "cup.and.saucer.fill"
    static let routine = "list.bullet.rectangle"
    static let planCatalog = "books.vertical.fill"
    static let checkIn = "text.book.closed"
    static let supplement = "drop.fill"
    static let stop = "stop.fill"
    static let timer = "timer"
    static let chart = "chart.xyaxis.line"
    static let progression = "chart.line.uptrend.xyaxis"
    static let trendUp = "arrow.up.right"
    static let trendDown = "arrow.down.right"
    static let trendFlat = "arrow.right"
    static let trophy = "trophy.fill"
    static let plateCalculator = "circle.grid.3x3.fill"
    static let muscles = "figure.strengthtraining.traditional"
    static let advanced = "slider.horizontal.3"
    static let effort = "gauge.with.needle"
    static let warmup = "flame"
    static let relationship = "arrow.triangle.branch"
    static let recipePhoto = "photo.badge.plus"
    static let recipePhotoReplace = "arrow.triangle.2.circlepath"
    static let recipeGenerate = "wand.and.stars"
    static let search = "magnifyingglass"

    // Workout focus. Reinforcement only — the focus name always accompanies
    // these in filters and rows, so meaning never rests on the glyph.
    static let focusFullBody = "figure.strengthtraining.functional"
    static let focusUpperBody = "figure.strengthtraining.traditional"
    static let focusLowerBody = "figure.step.training"
    static let focusCore = "figure.core.training"
    static let fastForward = "forward.fill"
    static let warningFill = "exclamationmark.triangle.fill"

    // Settings Groups
    // One glyph per settings destination, so the hub can be scanned by shape
    // before it is read. Deliberately literal — the icon repeats the label
    // rather than replacing it, since none of these rows is icon-only.
    static let appearance = "circle.lefthalf.filled"
    static let units = "ruler"
    static let bodyWeight = "scalemass"
    static let reminders = "bell.badge"
    static let siri = "sparkles"
    static let backup = "externaldrive"
}
