// TypeScript surface over the WidgetHandoff native module. iOS only;
// every call degrades to a no-op elsewhere, and on any binary that does
// not carry the module, so call sites never need a platform fork and an
// over-the-air update can never crash an older install.

import { requireOptionalNativeModule } from "expo-modules-core";
import { Platform } from "react-native";

export interface SessionActivityState {
  title: string;
  stepIndex: number;
  stepTotal: number;
  detail: string;
  /** Colours the detail line. */
  highlight: "gold" | "green" | null;
  count: number;
  /** Epoch ms. While in the future, the countdown is the hero. */
  countdownEndsAtMs: number | null;
}

export interface SessionActivityAttrs {
  sessionId: string;
  startedAtMs: number;
}

interface NativeBindings {
  writeWidgetData(json: string): boolean;
  clearWidgetData(): void;
  isLiveActivitySupported(): boolean;
  startActivity(attrs: SessionActivityAttrs, state: SessionActivityState): Promise<string | null>;
  updateActivity(state: SessionActivityState): Promise<boolean>;
  endActivity(): Promise<boolean>;
}

const native =
  Platform.OS === "ios" ? requireOptionalNativeModule<NativeBindings>("WidgetHandoff") : null;

/** False on Android, in Expo Go, or any build that predates the module. */
export function isWidgetHandoffAvailable(): boolean {
  return native != null;
}

export function writeWidgetData(json: string): boolean {
  if (!native) return false;
  return native.writeWidgetData(json);
}

export function clearWidgetData(): void {
  if (!native) return;
  native.clearWidgetData();
}

export function isLiveActivitySupported(): boolean {
  if (!native) return false;
  return native.isLiveActivitySupported();
}

export async function startLiveActivity(
  attrs: SessionActivityAttrs,
  state: SessionActivityState,
): Promise<string | null> {
  if (!native) return null;
  try {
    return await native.startActivity(attrs, state);
  } catch {
    return null;
  }
}

export async function updateLiveActivity(state: SessionActivityState): Promise<boolean> {
  if (!native) return false;
  try {
    return await native.updateActivity(state);
  } catch {
    return false;
  }
}

export async function endLiveActivity(): Promise<boolean> {
  if (!native) return false;
  try {
    return await native.endActivity();
  } catch {
    return false;
  }
}
