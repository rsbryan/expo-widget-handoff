# expo-widget-handoff

A working handoff between an Expo app and its iOS widget extension: a
home-screen widget fed through an App Group, and a Live Activity with a
Dynamic Island, driven from TypeScript. Carved out of
[The Lifting App](https://github.com/rsbryan/the-lifting-app), where it
has been on real lock screens since May 2026.

About 1,400 lines of TypeScript and Swift. No npm package, no config
plugin magic. Copy the two folders into your project, change three
identifiers, and read the rules at the bottom, because every one of
them cost a bug on a device.

## What's here

```
module/            A local Expo module (iOS only)
  src/index.ts       JS surface. Every call is a no-op on Android, in
                     Expo Go, and on any binary that lacks the module.
  ios/*.swift        App Group writer + ActivityKit start/update/end.
widget/            A widget extension for @bacons/apple-targets
  TodayWidget.swift        Small and medium home-screen widget.
  SessionActivity.swift    Lock screen card + Dynamic Island.
  SessionActivityAttributes.swift
src/
  widgetPayload.ts            The JSON contract, and a diagnostic.
  liveActivityCoordinator.ts  Idempotent reconcile + explicit end.
```

## Setup

1. Copy `module/` to `modules/widget-handoff/` and add it to
   `package.json`:

   ```json
   "widget-handoff": "file:./modules/widget-handoff"
   ```

2. Copy `widget/` to `targets/widgets/` and add the plugin to
   `app.config.ts`:

   ```ts
   plugins: ["@bacons/apple-targets"],
   ios: {
     entitlements: {
       "com.apple.security.application-groups": ["group.com.example.app.widgets"],
     },
   },
   ```

3. Change the three identifiers to yours:
   - the App Group, in `module/ios/WidgetHandoffModule.swift`,
     `widget/TodayWidget.swift`, `widget/expo-target.config.json`, and
     the app's entitlements. All four must match.
   - the URL scheme, in `widget/SessionActivity.swift`. The "End
     session" button is a plain `Link` to
     `scheme://session/<id>?action=end`, so your deep-link handler ends
     the session and the activity together.
   - the module name, if you rename it: `Name("WidgetHandoff")` in
     Swift and `requireOptionalNativeModule("WidgetHandoff")` in TS.

4. Build a dev client. Widgets and Live Activities are native; they do
   not ship over the air.

## Using it

Write the widget after anything that could change it:

```ts
import { syncTodayWidget } from "./src/widgetPayload";

syncTodayWidget({
  title: "Push",
  isActive: sessionOpen,
  items: todaysLifts.map((l) => ({ name: l.name, detail: l.lastTopSet })),
  streakDays: 3,
  weekCount: 24,
  weekTotalDisplay: "18,400 lb",
});
```

Drive the Live Activity from wherever your session state lives, as
often as you like:

```ts
import { reconcileLiveActivity, endLiveActivityCoordinator } from "./src/liveActivityCoordinator";

reconcileLiveActivity({
  sessionId,
  startedAtMs,
  title: "Bench Press",
  stepIndex: 2,
  stepTotal: 4,
  detail: "225 lb x 8",
  highlight: "gold",          // or "green" or null
  count: 11,
  countdownEndsAtMs: restEndsAt, // or null
});

// When the session ends. Await it before navigating.
await endLiveActivityCoordinator(sessionId);
```

A settings row that calls `diagnoseWidget()` tells you, on a device,
whether the module is in the binary and whether the App Group write
succeeded. Those are the two things that go wrong, and they look
identical from the outside (a blank widget).

## The rules

Each of these is a bug that shipped once.

**Every field added after version 1 is optional in Swift.** The widget
decodes whatever the installed app last wrote. After an over-the-air
update the app writes a newer shape than the widget binary knows; after
a native update the widget may read a payload an older app wrote. A
single non-optional field makes the whole decode fail and the widget
goes blank. Never remove or rename a field.

**Probe the module, never assume it.** `requireOptionalNativeModule`
returns null on any binary that predates the module. Over-the-air
updates reach those binaries too, and an unconditional native require
throws on launch for every one of them.

**`Text(timerInterval:)` reserves width for its widest value and ignores
`minimumScaleFactor`.** A session timer in a clamped trailing column
clips at the card edge. Put timers in leading-aligned rows with free
trailing space, or cap the interval so the reservation is "99:59" (five
characters) instead of "99:00:00" (eight). The compact island chip here
does the latter and freezes past 100 minutes; the expanded view keeps
true time.

**Set a stale date at the countdown's end.** The phone is usually locked
when a rest timer expires, so no update arrives. With `staleDate` set,
the system re-renders the views at that moment and `context.isStale`
lets them swap the frozen "0:00" for the last-set line.

**Serialize every reconcile and end.** Two reconciles that both saw
`started = false` both called start; the native end-existing-first
sweeps raced each other and two cards stacked on the lock screen. One
promise chain, every call waits for the previous one.

**Tombstone the session before the end lands.** A reconcile queued
behind an end, or an effect re-firing during teardown, re-creates the
activity from scratch. That is the island still glowing after the
workout is over. The ended id is recorded synchronously, before the end
joins the chain, so any later reconcile for it is a no-op.

**Await the end before navigating.** Fire-and-forget races app
suspension and the end never reaches ActivityKit.

**Don't cache state until the native side took it.** ActivityKit updates
are budget-limited and can be rejected. Caching the payload before the
await marked a failed write as delivered, and every later reconcile with
the same state was skipped, leaving the card stuck.

**End every alive activity, not the one you remember.** The in-memory
reference resets on each JS reload while iOS keeps activities alive
across restarts. Start sweeps all existing activities first, and end
sweeps all of them, so a stale card can never survive a reload.

## License

MIT.
