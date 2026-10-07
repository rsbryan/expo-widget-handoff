// Mirror of widget/SessionActivityAttributes.swift. Both copies describe
// the same ActivityKit attributes; they live in two targets (the main
// app and the widget extension) and must be kept in sync.
//
// If you change one, change the other.

import ActivityKit
import Foundation

public struct SessionActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    public var title: String
    public var stepIndex: Int
    public var stepTotal: Int
    public var detail: String
    /// "gold", "green", or nil. Colours the detail line.
    public var highlight: String?
    public var count: Int
    /// Epoch milliseconds. While this is in the future the countdown is
    /// the hero; the content's stale date is set to it.
    public var countdownEndsAtMs: Double?

    public init(
      title: String,
      stepIndex: Int,
      stepTotal: Int,
      detail: String,
      highlight: String?,
      count: Int,
      countdownEndsAtMs: Double?
    ) {
      self.title = title
      self.stepIndex = stepIndex
      self.stepTotal = stepTotal
      self.detail = detail
      self.highlight = highlight
      self.count = count
      self.countdownEndsAtMs = countdownEndsAtMs
    }
  }

  public var sessionId: String
  public var startedAtMs: Double

  public init(sessionId: String, startedAtMs: Double) {
    self.sessionId = sessionId
    self.startedAtMs = startedAtMs
  }
}
