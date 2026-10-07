// Widget extension entry point: every widget and Live Activity the
// extension exposes.

import SwiftUI
import WidgetKit

@main
struct WidgetsBundle: WidgetBundle {
  var body: some Widget {
    TodayWidget()
    if #available(iOS 16.2, *) {
      SessionActivity()
    }
  }
}
