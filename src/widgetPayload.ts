// The JSON the app writes for the home-screen widget, and the one rule
// that keeps the pair working across app versions.
//
// The widget decodes whatever the installed app last wrote. After an
// over-the-air update the app may write a newer shape than the widget
// binary knows, and after a native update the widget may read a payload
// an older app wrote. So: never remove or rename a field, and every
// field added after version 1 is optional on the Swift side. This file
// is the source of truth; widget/TodayWidget.swift mirrors it.

import { clearWidgetData, isWidgetHandoffAvailable, writeWidgetData } from "../module/src";

export interface TodayItem {
  name: string;
  detail: string | null;
}

export interface TodayPayload {
  version: 1;
  updatedAt: string;
  title: string;
  isActive: boolean;
  items: TodayItem[];
  // Added after version 1. Optional in Swift.
  streakDays?: number;
  weekCount?: number;
  weekTotalDisplay?: string;
}

export const MAX_ITEMS = 5;

/**
 * Write the payload for the widget. Idempotent: call it after every
 * mutation that could change what the widget shows; the latest write
 * wins. Fire and forget: the native write returns false when the App
 * Group is not entitled (simulator, a misconfigured build) and callers
 * do not need to know.
 */
export function syncTodayWidget(payload: Omit<TodayPayload, "version" | "updatedAt">): void {
  const full: TodayPayload = {
    version: 1,
    updatedAt: new Date().toISOString(),
    ...payload,
    items: payload.items.slice(0, MAX_ITEMS),
  };
  try {
    writeWidgetData(JSON.stringify(full));
  } catch {
    // Native module unavailable in this context.
  }
}

/** Call on sign-out so the next account does not inherit the widget. */
export function clearTodayWidget(): void {
  try {
    clearWidgetData();
  } catch {
    // ignore
  }
}

export interface WidgetDiagnostics {
  /** Is the module compiled into this binary? */
  nativeAvailable: boolean;
  /** Did the App Group write succeed? False while nativeAvailable is
   *  true points at an entitlement or provisioning gap. */
  writeOk: boolean;
}

/**
 * Write a known payload and report what happened. If the widget then
 * shows "Widget test", the whole write, App Group, read, render pipe
 * works. Put this behind a row in a settings screen so widget issues
 * can be triaged on a device without a rebuild.
 */
export function diagnoseWidget(): WidgetDiagnostics {
  const nativeAvailable = isWidgetHandoffAvailable();
  const payload: TodayPayload = {
    version: 1,
    updatedAt: new Date().toISOString(),
    title: "Diagnostic",
    isActive: false,
    items: [{ name: "Widget test", detail: "OK" }],
  };
  let writeOk = false;
  try {
    writeOk = writeWidgetData(JSON.stringify(payload));
  } catch {
    writeOk = false;
  }
  return { nativeAvailable, writeOk };
}
