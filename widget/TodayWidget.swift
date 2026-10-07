// Home-screen widget showing a title and a short list of items with a
// detail line each. Data is written by the app into the shared App
// Group's UserDefaults and refreshed whenever the app writes.
//
// The read path is one-way: the widget never writes. If the app has not
// written yet, the widget renders a placeholder.
//
// The one rule that keeps this working across app versions: every
// field added after version 1 is OPTIONAL here. A widget decodes
// whatever the installed app last wrote, which may be an older payload,
// and one non-optional field makes the whole decode fail and the widget
// go blank.

import SwiftUI
import WidgetKit

private let appGroup = "group.com.example.app.widgets"
private let storageKey = "today"

// MARK: - Data shape (matches src/widgetPayload.ts)

struct TodayPayload: Codable {
  var version: Int
  var updatedAt: String?
  var title: String
  var isActive: Bool
  var items: [TodayItem]
  // Added after version 1. Optional so older payloads still decode.
  var streakDays: Int?
  var weekCount: Int?
  var weekTotalDisplay: String?
}

struct TodayItem: Codable, Identifiable {
  var name: String
  var detail: String?
  var id: String { name }
}

// MARK: - Timeline provider

struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayEntry {
    TodayEntry(date: Date(), payload: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
    completion(TodayEntry(date: Date(), payload: loadPayload()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    let entry = TodayEntry(date: Date(), payload: loadPayload())
    // Hourly backstop. The app reloads timelines whenever it writes, so
    // most refreshes are driven by the user.
    let next = Date().addingTimeInterval(60 * 60)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

struct TodayEntry: TimelineEntry {
  let date: Date
  let payload: TodayPayload
}

private func loadPayload() -> TodayPayload {
  guard
    let defaults = UserDefaults(suiteName: appGroup),
    let raw = defaults.string(forKey: storageKey),
    let data = raw.data(using: .utf8),
    let decoded = try? JSONDecoder().decode(TodayPayload.self, from: data)
  else {
    return .empty
  }
  return decoded
}

extension TodayPayload {
  static let placeholder = TodayPayload(
    version: 1,
    updatedAt: nil,
    title: "Push",
    isActive: false,
    items: [
      TodayItem(name: "Bench Press", detail: "195 x 4"),
      TodayItem(name: "Overhead Press", detail: "115 x 5"),
      TodayItem(name: "Triceps Pushdown", detail: "55 x 12"),
    ],
    streakDays: 3,
    weekCount: 24,
    weekTotalDisplay: "18,400 lb"
  )

  static let empty = TodayPayload(
    version: 1, updatedAt: nil, title: "\u{2014}", isActive: false, items: [],
    streakDays: nil, weekCount: nil, weekTotalDisplay: nil
  )
}

// MARK: - View

struct TodayWidgetEntryView: View {
  var entry: TodayEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .systemSmall:
      smallBody.containerBackground(for: .widget) { Color(.systemBackground) }
    default:
      mediumBody
    }
  }

  private var streak: Int { entry.payload.streakDays ?? 0 }

  private var eyebrow: some View {
    Text(entry.payload.isActive ? "IN SESSION" : "TODAY")
      .font(.system(size: 9, weight: .heavy))
      .tracking(1.4)
      .foregroundStyle(entry.payload.isActive ? Color.primary : Color.secondary)
  }

  private var streakBadge: some View {
    HStack(spacing: 3) {
      Image(systemName: "flame.fill").font(.system(size: 9, weight: .bold))
      Text("\(streak)").font(.system(size: 11, weight: .heavy)).monospacedDigit()
    }
    .foregroundStyle(Brand.gold)
  }

  private var smallBody: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        eyebrow
        Spacer()
        if streak > 0 { streakBadge }
      }
      Spacer(minLength: 4)
      Text(entry.payload.title)
        .font(.system(size: 26, weight: .heavy))
        .tracking(-0.8)
        .lineLimit(2)
        .minimumScaleFactor(0.6)
      Spacer(minLength: 4)
      if let total = entry.payload.weekTotalDisplay,
        let weekCount = entry.payload.weekCount, weekCount > 0 {
        Text(total).font(.system(size: 13, weight: .heavy)).monospacedDigit()
        Text("\(weekCount) THIS WEEK")
          .font(.system(size: 8, weight: .heavy))
          .tracking(1.0)
          .foregroundStyle(.secondary)
          .padding(.top, 1)
      } else if entry.payload.items.isEmpty {
        Text(entry.payload.isActive ? "In progress" : "Nothing planned")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
      } else {
        Text("\(entry.payload.items.count) queued")
          .font(.system(size: 12, weight: .semibold))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(2)
  }

  private var mediumBody: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 0) {
        eyebrow
        Text(entry.payload.title)
          .font(.system(size: 24, weight: .heavy))
          .tracking(-0.7)
          .lineLimit(2)
          .minimumScaleFactor(0.6)
          .padding(.top, 3)
        Spacer(minLength: 4)
        if streak > 0 {
          HStack(spacing: 4) {
            Image(systemName: "flame.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Brand.gold)
            Text("\(streak)-day streak").font(.system(size: 11, weight: .bold)).foregroundStyle(Brand.gold)
          }
          .padding(.bottom, 3)
        }
        if let total = entry.payload.weekTotalDisplay,
          let weekCount = entry.payload.weekCount, weekCount > 0 {
          Text(total).font(.system(size: 15, weight: .heavy)).monospacedDigit()
          Text("\(weekCount) THIS WEEK")
            .font(.system(size: 8, weight: .heavy))
            .tracking(1.0)
            .foregroundStyle(.secondary)
            .padding(.top, 1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(alignment: .leading, spacing: 5) {
        if entry.payload.items.isEmpty {
          Spacer()
          Text(entry.payload.isActive ? "In progress" : "Nothing planned")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
          Spacer()
        } else {
          ForEach(entry.payload.items.prefix(4)) { item in
            VStack(alignment: .leading, spacing: 0) {
              Text(item.name).font(.system(size: 12.5, weight: .bold)).lineLimit(1)
              if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                  .font(.system(size: 11, weight: .medium))
                  .foregroundStyle(.secondary)
                  .monospacedDigit()
                  .lineLimit(1)
              }
            }
          }
          Spacer(minLength: 0)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 2)
    .containerBackground(for: .widget) { Color(.systemBackground) }
  }
}

// MARK: - Widget configuration

struct TodayWidget: Widget {
  let kind: String = "TodayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
      TodayWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Today")
    .description("What is planned today, at a glance.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
