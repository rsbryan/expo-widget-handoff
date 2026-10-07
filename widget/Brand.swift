// Colour tokens for the extension. The Live Activity always renders on
// a dark system surface, so these are the dark-theme values.

import SwiftUI

enum Brand {
  static let accent = Color(red: 242 / 255, green: 242 / 255, blue: 241 / 255)
  static let gold = Color(red: 212 / 255, green: 160 / 255, blue: 23 / 255)
  static let green = Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255)
  static let darkBg = Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255)
  /// Elapsed timers stop counting here. The cap doubles as the width
  /// Text(timerInterval:) reserves, see SessionActivity.swift.
  static let maxSessionSeconds: TimeInterval = 99 * 3600
}
