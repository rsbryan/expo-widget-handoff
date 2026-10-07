// WidgetHandoff: an iOS-only Expo module with two surfaces for JS.
//
// 1. App Group widget data writer.
//    `writeWidgetData(json)` stores the string under a fixed key in the
//    shared App Group's UserDefaults so the widget extension's
//    TimelineProvider can read it, then asks WidgetCenter to reload so
//    the widget refreshes now instead of at its next scheduled tick.
//
// 2. ActivityKit Live Activity controls.
//    `startActivity`, `updateActivity`, `endActivity` wrap the iOS 16.2+
//    Activity APIs for a single activity at a time. The current activity
//    is tracked in memory; after a cold start the OS may still have one
//    alive, so `resolveCurrentActivity` re-attaches to it through
//    Activity<...>.activities. Start ends every alive activity first and
//    end ends every alive activity, so a race can never leave two cards
//    stacked on the lock screen.
//
// Change these two constants to your own identifiers. The App Group must
// match the one in widget/expo-target.config.json and in the app's own
// entitlements.

import ActivityKit
import ExpoModulesCore
import Foundation
import WidgetKit

private let appGroup = "group.com.example.app.widgets"
private let widgetStorageKey = "today"

public class WidgetHandoffModule: Module {
  private var currentActivityRef: Any?

  public func definition() -> ModuleDefinition {
    Name("WidgetHandoff")

    // MARK: - Widget data

    /// JS passes the already-serialised string so the encoding rules
    /// stay on the JS side, next to the TypeScript type.
    Function("writeWidgetData") { (json: String) -> Bool in
      guard let defaults = UserDefaults(suiteName: appGroup) else {
        return false
      }
      defaults.set(json, forKey: widgetStorageKey)
      WidgetCenter.shared.reloadAllTimelines()
      return true
    }

    /// Call on sign-out so the widget stops showing the previous
    /// account's data on a shared device.
    Function("clearWidgetData") { () -> Void in
      guard let defaults = UserDefaults(suiteName: appGroup) else { return }
      defaults.removeObject(forKey: widgetStorageKey)
      WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Live Activity

    Function("isLiveActivitySupported") { () -> Bool in
      if #available(iOS 16.2, *) {
        return ActivityAuthorizationInfo().areActivitiesEnabled
      }
      return false
    }

    AsyncFunction("startActivity") {
      (attrs: [String: Any], state: [String: Any]) -> String? in
      guard #available(iOS 16.2, *) else { return nil }
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }

      for existing in Activity<SessionActivityAttributes>.activities {
        await existing.end(nil, dismissalPolicy: .immediate)
      }
      self.currentActivityRef = nil

      let attributes = SessionActivityAttributes(
        sessionId: attrs["sessionId"] as? String ?? "",
        startedAtMs: attrs["startedAtMs"] as? Double ?? 0
      )
      let contentState = decodeState(state)
      let content = ActivityContent(
        state: contentState,
        staleDate: staleDateFor(contentState)
      )

      do {
        let activity = try Activity<SessionActivityAttributes>.request(
          attributes: attributes,
          content: content,
          pushType: nil
        )
        self.currentActivityRef = activity
        return activity.id
      } catch {
        return nil
      }
    }

    AsyncFunction("updateActivity") { (state: [String: Any]) -> Bool in
      guard #available(iOS 16.2, *) else { return false }
      guard let activity = self.resolveCurrentActivity() else { return false }
      let contentState = decodeState(state)
      let content = ActivityContent(
        state: contentState,
        staleDate: staleDateFor(contentState)
      )
      await activity.update(content)
      return true
    }

    AsyncFunction("endActivity") { () -> Bool in
      guard #available(iOS 16.2, *) else { return false }
      var ended = false
      for activity in Activity<SessionActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
        ended = true
      }
      self.currentActivityRef = nil
      return ended
    }
  }

  @available(iOS 16.2, *)
  private func resolveCurrentActivity() -> Activity<SessionActivityAttributes>? {
    if let ref = currentActivityRef as? Activity<SessionActivityAttributes> {
      return ref
    }
    let active = Activity<SessionActivityAttributes>.activities.first
    currentActivityRef = active
    return active
  }
}

/// Content goes stale the moment the countdown ends. The app is usually
/// suspended then (phone locked), so no update arrives; staleness makes
/// the system re-render the views, which check `context.isStale` and
/// swap the frozen "0:00" back to the detail line.
@available(iOS 16.2, *)
private func staleDateFor(
  _ state: SessionActivityAttributes.ContentState
) -> Date? {
  guard let endsMs = state.countdownEndsAtMs else { return nil }
  let date = Date(timeIntervalSince1970: endsMs / 1000.0)
  return date > Date() ? date : nil
}

/// Missing or wrongly typed keys fall through to safe defaults so a
/// malformed JS payload cannot crash the activity update.
@available(iOS 16.2, *)
private func decodeState(_ raw: [String: Any]) -> SessionActivityAttributes.ContentState {
  let rawHighlight = raw["highlight"] as? String
  let highlight = (rawHighlight == "gold" || rawHighlight == "green") ? rawHighlight : nil
  let countdownEndsAtMs: Double?
  if let v = raw["countdownEndsAtMs"] as? Double {
    countdownEndsAtMs = v
  } else if let v = raw["countdownEndsAtMs"] as? Int {
    countdownEndsAtMs = Double(v)
  } else {
    countdownEndsAtMs = nil
  }
  return SessionActivityAttributes.ContentState(
    title: raw["title"] as? String ?? "",
    stepIndex: raw["stepIndex"] as? Int ?? 0,
    stepTotal: raw["stepTotal"] as? Int ?? 0,
    detail: raw["detail"] as? String ?? "",
    highlight: highlight,
    count: raw["count"] as? Int ?? 0,
    countdownEndsAtMs: countdownEndsAtMs
  )
}
