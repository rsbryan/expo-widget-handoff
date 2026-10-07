// Live Activity and Dynamic Island UI for an in-progress session.
//
// Content states switch on `countdownEndsAtMs`:
//   - present and in the future: the countdown is the hero
//   - nil or past: the detail line is the hero
//
// `highlight` colours the detail: gold, green, or plain.
//
// Layout rule learned the hard way: Text(timerInterval:) reserves width
// for its widest possible rendering ("99:00:00") and ignores
// minimumScaleFactor, so a timer must never sit in a clamped trailing
// column; it clips at the card edge. Timers here live in leading
// aligned rows with a trailing Spacer, or use a short interval cap so
// the reserved width is small.
//
// Surfaces, per ActivityKit:
//   - lockScreen: the rectangular card, also on phones without an island
//   - dynamicIslandExpanded: long-press view in the island
//   - dynamicIslandCompact: leading and trailing chips
//   - dynamicIslandMinimal: when another activity shares the island

import ActivityKit
import SwiftUI
import WidgetKit

// Change to your app's URL scheme. The end link routes through the
// app's deep-link handler, which finishes the session and ends the
// activity.
private let urlScheme = "exampleapp"

@available(iOS 16.2, *)
struct SessionActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SessionActivityAttributes.self) { context in
      SessionLockScreenView(
        state: context.state,
        startedAtMs: context.attributes.startedAtMs,
        sessionId: context.attributes.sessionId,
        isStale: context.isStale
      )
      .activityBackgroundTint(Brand.darkBg.opacity(0.92))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "circle.fill")
            .foregroundStyle(Brand.accent)
            .font(.system(size: 18, weight: .bold))
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 1) {
            // 13pt keeps the 8-character reservation inside the 88pt
            // clamp; 15pt overflowed and clipped.
            ElapsedText(startedAtMs: context.attributes.startedAtMs)
              .font(.system(size: 13, weight: .heavy, design: .rounded))
              .monospacedDigit()
              .lineLimit(1)
              .multilineTextAlignment(.trailing)
              .foregroundStyle(.white)
              .frame(maxWidth: 88, alignment: .trailing)
            Text("\(context.state.count) DONE")
              .font(.system(size: 8, weight: .heavy))
              .tracking(1.0)
              .foregroundStyle(.white.opacity(0.5))
          }
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(alignment: .leading, spacing: 1) {
            Text(context.state.title)
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.white)
              .lineLimit(1)
            if let endsMs = context.state.countdownEndsAtMs,
              !context.isStale, isCountingDown(context.state) {
              HStack(spacing: 5) {
                Text("REST")
                  .font(.system(size: 9, weight: .heavy))
                  .tracking(1.0)
                  .foregroundStyle(.white.opacity(0.55))
                CountdownText(targetMs: endsMs)
                  .font(.system(size: 11, weight: .semibold, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(.white.opacity(0.85))
              }
            } else if !context.state.detail.isEmpty {
              DetailLine(state: context.state, fontSize: 11)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Link(destination: endURL(context.attributes.sessionId)) {
            Text("End session")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(Brand.darkBg)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 7)
              .background(Brand.accent, in: Capsule())
          }
        }
      } compactLeading: {
        Image(systemName: "circle.fill").foregroundStyle(Brand.accent)
      } compactTrailing: {
        // Countdown while counting down (short interval, small
        // reservation), otherwise elapsed time capped at 99:59 so the
        // reservation is 5 characters, not 8. Past that the compact
        // chip freezes; the expanded island and lock screen keep time.
        if let endsMs = context.state.countdownEndsAtMs,
          !context.isStale, isCountingDown(context.state) {
          CountdownText(targetMs: endsMs)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(Color.white)
            .frame(maxWidth: 48, alignment: .trailing)
        } else {
          ElapsedText(startedAtMs: context.attributes.startedAtMs, capSeconds: 5999)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(Color.white)
            .frame(maxWidth: 48, alignment: .trailing)
        }
      } minimal: {
        Image(systemName: "circle.fill").foregroundStyle(Brand.accent)
      }
      .widgetURL(URL(string: "\(urlScheme)://session/\(context.attributes.sessionId)"))
      .keylineTint(Brand.accent)
    }
  }
}

// MARK: - Lock-screen card

@available(iOS 16.2, *)
struct SessionLockScreenView: View {
  let state: SessionActivityAttributes.ContentState
  let startedAtMs: Double
  let sessionId: String
  /// True once the countdown's stale date passed: the app was likely
  /// suspended and could not push fresh state, so render the detail
  /// hero instead of a frozen "0:00".
  let isStale: Bool

  private var countingDown: Bool {
    state.countdownEndsAtMs != nil && !isStale && isCountingDown(state)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(state.title)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(.white.opacity(0.85))
        .lineLimit(1)

      if countingDown, let endsMs = state.countdownEndsAtMs {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          CountdownText(targetMs: endsMs)
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(.white)
          Text("REST")
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.4)
            .foregroundStyle(.white.opacity(0.5))
          Spacer(minLength: 8)
          if !state.detail.isEmpty {
            DetailLine(state: state, fontSize: 12)
          }
        }
      } else if !state.detail.isEmpty {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(state.detail)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(heroColor)
          if let badge = heroBadge {
            Text(badge)
              .font(.system(size: 10, weight: .heavy))
              .tracking(1.2)
              .foregroundStyle(heroColor)
          }
          Spacer(minLength: 0)
        }
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          ElapsedText(startedAtMs: startedAtMs)
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(.white)
          Text("ELAPSED")
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.4)
            .foregroundStyle(.white.opacity(0.5))
          Spacer(minLength: 0)
        }
      }

      // Leading aligned with free trailing space, so the timer's
      // reserved width can never clip.
      HStack(spacing: 6) {
        Text("STEP \(state.stepIndex)/\(state.stepTotal)")
          .font(.system(size: 10, weight: .heavy))
          .tracking(1.0)
          .foregroundStyle(.white.opacity(0.55))
        MetaDot()
        Text("\(state.count) DONE")
          .font(.system(size: 10, weight: .heavy))
          .tracking(1.0)
          .foregroundStyle(.white.opacity(0.55))
        MetaDot()
        ElapsedText(startedAtMs: startedAtMs)
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .lineLimit(1)
          .foregroundStyle(.white.opacity(0.75))
        Spacer(minLength: 0)
      }

      Link(destination: endURL(sessionId)) {
        Text("End session")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(Brand.darkBg)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(Brand.accent, in: Capsule())
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }

  private var heroColor: Color {
    switch state.highlight {
    case "gold": return Brand.gold
    case "green": return Brand.green
    default: return .white
    }
  }

  private var heroBadge: String? {
    switch state.highlight {
    case "gold": return "BEST"
    case "green": return "UP"
    default: return nil
    }
  }
}

@available(iOS 16.2, *)
struct MetaDot: View {
  var body: some View {
    Circle().fill(.white.opacity(0.3)).frame(width: 2.5, height: 2.5)
  }
}

@available(iOS 16.2, *)
struct DetailLine: View {
  let state: SessionActivityAttributes.ContentState
  let fontSize: CGFloat

  var body: some View {
    switch state.highlight {
    case "gold":
      Text("Best \u{00B7} \(state.detail)")
        .font(.system(size: fontSize, weight: .bold))
        .foregroundStyle(Brand.gold)
        .monospacedDigit()
        .lineLimit(1)
    case "green":
      Text("Up \u{00B7} \(state.detail)")
        .font(.system(size: fontSize, weight: .bold))
        .foregroundStyle(Brand.green)
        .monospacedDigit()
        .lineLimit(1)
    default:
      Text("Last \(state.detail)")
        .font(.system(size: fontSize, weight: .medium))
        .foregroundStyle(.white.opacity(0.7))
        .monospacedDigit()
        .lineLimit(1)
    }
  }
}

@available(iOS 16.2, *)
func endURL(_ sessionId: String) -> URL {
  URL(string: "\(urlScheme)://session/\(sessionId)?action=end")!
}

@available(iOS 16.2, *)
func isCountingDown(_ state: SessionActivityAttributes.ContentState) -> Bool {
  guard let endsMs = state.countdownEndsAtMs else { return false }
  return Date(timeIntervalSince1970: endsMs / 1000.0).timeIntervalSinceNow > 0
}

// MARK: - Timer helpers

/// Live MM:SS text driven by a target epoch. Text(timerInterval:) lets
/// the system tick it; a Timer does not run inside a widget.
@available(iOS 16.2, *)
struct CountdownText: View {
  let targetMs: Double

  var body: some View {
    let target = Date(timeIntervalSince1970: targetMs / 1000.0)
    if target.timeIntervalSinceNow <= 0 {
      Text("0:00")
    } else {
      Text(timerInterval: Date()...target, countsDown: true)
    }
  }
}

/// Elapsed time counting up from the start. The interval's upper bound
/// doubles as the width Text(timerInterval:) reserves: a tighter cap
/// means a narrower reservation, at the cost of freezing past the cap.
@available(iOS 16.2, *)
struct ElapsedText: View {
  let startedAtMs: Double
  var capSeconds: TimeInterval = Brand.maxSessionSeconds

  var body: some View {
    let start = Date(timeIntervalSince1970: startedAtMs / 1000.0)
    let cap = start.addingTimeInterval(capSeconds)
    if cap.timeIntervalSinceNow <= 0 {
      Text(capSeconds >= 6000 ? "99:00:00" : "99:59")
    } else {
      Text(timerInterval: start...cap, countsDown: false)
    }
  }
}
