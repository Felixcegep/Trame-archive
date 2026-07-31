import SwiftUI

/// **Lift and Lock** — the signature brand animation.
///
/// Compress, rise, lock, one settle beat, then absolute stillness. It means
/// *effort completed and secured*: the moment work becomes recorded truth.
/// Reserve it for saving a workout, a confirmed PR, the end of onboarding, a
/// restored backup, a milestone. Never after an ordinary set, and never as
/// decoration in a header.
///
/// The symbol carries the whole movement; the wordmark only fades and slides
/// a few points, and never rotates or scales. The shadow reports height —
/// it widens, lightens, and softens as the mark rises, which is what stops
/// the scale change from reading as a zoom.
///
/// Reduce Motion is handled here rather than at call sites, so no placement
/// can forget it.
struct TrameLiftAndLock: View {
    enum Variant {
        /// 900 ms. Important successes only.
        case signature
        /// A shortened launch variant. Same grammar, same keyframes, same
        /// proportions — only faster, because the first frame of the app is
        /// the one moment a user is waiting rather than celebrating.
        case launch

        var duration: TimeInterval {
            switch self {
            case .signature: 0.900
            case .launch: 0.620
            }
        }

        /// How much to compress every segment by, relative to the authored
        /// 900 ms timeline.
        var timeScale: Double { duration / 0.900 }
    }

    var variant: Variant = .signature
    var markHeight: CGFloat = 88
    var showsWordmark: Bool = true
    var color: Color = .trameMark
    /// Replays whenever this value changes. It also plays once on appear.
    var trigger: Int = 0
    /// Called when the animation has come fully to rest — for a launch or
    /// confirmation overlay that dismisses itself.
    var onFinish: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plays = 0

    /// The identity authored its travel and blur in pixels against an 88pt
    /// symbol. Scaling them keeps the *proportions* of the movement intact at
    /// any size — at 44pt an unscaled 19pt lift would throw the mark clear of
    /// its own shadow.
    private var unit: CGFloat { markHeight / 88 }

    var body: some View {
        Group {
            if reduceMotion {
                KeyframeAnimator(initialValue: LiftFrame.reducedStart, trigger: plays) { frame in
                    lockup(frame)
                } keyframes: { _ in
                    // Opacity and a 97% → 100% resolve. No travel, no
                    // rotation, no settle: completion still reads, because
                    // the mark arrives at its exact final position.
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1.0, duration: 0.320, timingCurve: AppMotion.lockCurve)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(1.0, duration: 0.320, timingCurve: AppMotion.lockCurve)
                    }
                    KeyframeTrack(\.wordmarkOpacity) {
                        LinearKeyframe(1.0, duration: 0.320, timingCurve: AppMotion.lockCurve)
                    }
                }
            } else {
                KeyframeAnimator(initialValue: LiftFrame.start, trigger: plays) { frame in
                    lockup(frame)
                } keyframes: { _ in
                    // Segment boundaries: 117 / 522 / 738 / 900 ms.
                    KeyframeTrack(\.lift) {
                        LinearKeyframe(13, duration: 0.117 * timeScale, timingCurve: AppMotion.prepareCurve)
                        LinearKeyframe(-6, duration: 0.405 * timeScale, timingCurve: AppMotion.liftCurve)
                        LinearKeyframe(1.5, duration: 0.216 * timeScale, timingCurve: AppMotion.lockCurve)
                        LinearKeyframe(0, duration: 0.162 * timeScale, timingCurve: AppMotion.settleCurve)
                    }
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(0.94, duration: 0.117 * timeScale, timingCurve: AppMotion.prepareCurve)
                        LinearKeyframe(1.018, duration: 0.405 * timeScale, timingCurve: AppMotion.liftCurve)
                        LinearKeyframe(0.996, duration: 0.216 * timeScale, timingCurve: AppMotion.lockCurve)
                        LinearKeyframe(1.0, duration: 0.162 * timeScale, timingCurve: AppMotion.settleCurve)
                    }
                    // Degrees *from rest*. The mark's 22° angle is already
                    // baked into its geometry, so these are the deltas the
                    // identity's absolute rotations describe — and they stay
                    // inside the family's 3° ceiling.
                    KeyframeTrack(\.roll) {
                        LinearKeyframe(-2.5, duration: 0.117 * timeScale, timingCurve: AppMotion.prepareCurve)
                        LinearKeyframe(1.6, duration: 0.405 * timeScale, timingCurve: AppMotion.liftCurve)
                        LinearKeyframe(-0.3, duration: 0.216 * timeScale, timingCurve: AppMotion.lockCurve)
                        LinearKeyframe(0, duration: 0.162 * timeScale, timingCurve: AppMotion.settleCurve)
                    }
                    // The shadow has no settle stop of its own: it re-seats
                    // across the lock and settle together, so it lands with
                    // the mark rather than before it.
                    KeyframeTrack(\.shadowWidth) {
                        LinearKeyframe(0.6, duration: 0.117 * timeScale, timingCurve: AppMotion.prepareCurve)
                        LinearKeyframe(1.22, duration: 0.405 * timeScale, timingCurve: AppMotion.liftCurve)
                        LinearKeyframe(1.0, duration: 0.378 * timeScale, timingCurve: AppMotion.lockCurve)
                    }
                    KeyframeTrack(\.shadowOpacity) {
                        LinearKeyframe(0.62, duration: 0.117 * timeScale, timingCurve: AppMotion.prepareCurve)
                        LinearKeyframe(0.22, duration: 0.405 * timeScale, timingCurve: AppMotion.liftCurve)
                        LinearKeyframe(0.40, duration: 0.378 * timeScale, timingCurve: AppMotion.lockCurve)
                    }
                    KeyframeTrack(\.shadowBlur) {
                        LinearKeyframe(0.5, duration: 0.117 * timeScale, timingCurve: AppMotion.prepareCurve)
                        LinearKeyframe(3.0, duration: 0.405 * timeScale, timingCurve: AppMotion.liftCurve)
                        LinearKeyframe(1.5, duration: 0.378 * timeScale, timingCurve: AppMotion.lockCurve)
                    }
                    // 470–810 ms: the wordmark is already arriving while the
                    // symbol locks, so the pair resolves together instead of
                    // the name appearing after the movement has stopped.
                    KeyframeTrack(\.wordmarkOpacity) {
                        LinearKeyframe(0, duration: 0.470 * timeScale)
                        LinearKeyframe(1, duration: 0.340 * timeScale, timingCurve: AppMotion.lockCurve)
                        LinearKeyframe(1, duration: 0.090 * timeScale)
                    }
                    KeyframeTrack(\.wordmarkSlide) {
                        LinearKeyframe(9, duration: 0.470 * timeScale)
                        LinearKeyframe(0, duration: 0.340 * timeScale, timingCurve: AppMotion.lockCurve)
                        LinearKeyframe(0, duration: 0.090 * timeScale)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Trame"))
        .onAppear { plays += 1 }
        .onChange(of: trigger) { plays += 1 }
        .task(id: plays) {
            guard plays > 0, onFinish != nil else { return }
            let runtime = reduceMotion ? 0.320 : variant.duration
            do {
                try await Task.sleep(for: .seconds(runtime))
            } catch {
                return // Replayed or removed before it finished.
            }
            onFinish?()
        }
    }

    private var timeScale: Double { variant.timeScale }

    private func lockup(_ frame: LiftFrame) -> some View {
        HStack(spacing: markHeight * 0.34) {
            ZStack {
                Ellipse()
                    // The identity's shadow opacities are of an already-faint
                    // ellipse, not of solid navy; this base keeps the peak
                    // around 17% so the mark never looks pasted onto a card.
                    .fill(Color.trameNavy.opacity(0.28 * frame.shadowOpacity))
                    .frame(width: markHeight * 0.88, height: markHeight * 0.09)
                    .scaleEffect(x: frame.shadowWidth, y: 1)
                    .blur(radius: unit * frame.shadowBlur)
                    .offset(y: markHeight * 0.58)

                TrameMarkView(height: markHeight, color: color)
                    .scaleEffect(frame.scale)
                    .rotationEffect(.degrees(frame.roll))
                    .offset(y: unit * frame.lift)
            }
            .frame(width: markHeight * TrameMark.aspectRatio, height: markHeight)
            .opacity(frame.opacity)

            if showsWordmark {
                TrameWordmark(color: color)
                    .offset(x: unit * frame.wordmarkSlide)
                    .opacity(frame.wordmarkOpacity)
            }
        }
    }
}

/// One animatable frame of Lift and Lock.
///
/// `lift`, `wordmarkSlide`, and `shadowBlur` are in the identity's 88pt
/// reference units and are multiplied by `unit` at draw time; `roll` is
/// degrees from rest.
private struct LiftFrame {
    var lift: CGFloat
    var scale: CGFloat
    var roll: Double
    var shadowWidth: CGFloat
    var shadowOpacity: Double
    var shadowBlur: CGFloat
    var wordmarkOpacity: Double
    var wordmarkSlide: CGFloat
    var opacity: Double

    /// Resting low, before the lift. Also what renders if the animation never
    /// runs, which is why the shadow is already seated rather than absent.
    static let start = LiftFrame(
        lift: 10,
        scale: 0.96,
        roll: -2,
        shadowWidth: 0.7,
        shadowOpacity: 0.5,
        shadowBlur: 1,
        wordmarkOpacity: 0,
        wordmarkSlide: 9,
        opacity: 1
    )

    /// Reduce Motion starts at rest geometry and only resolves scale and
    /// opacity — nothing travels or rotates.
    static let reducedStart = LiftFrame(
        lift: 0,
        scale: 0.97,
        roll: 0,
        shadowWidth: 1,
        shadowOpacity: 0.4,
        shadowBlur: 1.5,
        wordmarkOpacity: 0,
        wordmarkSlide: 0,
        opacity: 0
    )
}

#Preview("Lift and Lock") {
    @Previewable @State var replays = 0

    VStack(spacing: 56) {
        TrameLiftAndLock(trigger: replays)

        TrameLiftAndLock(variant: .launch, markHeight: 56, trigger: replays)

        Button("Replay") { replays += 1 }
            .buttonStyle(.gymPrimary)
            .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gymBackground)
}
