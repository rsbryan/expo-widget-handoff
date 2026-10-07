// One `reconcileLiveActivity` call that idempotently starts the activity
// on first use and updates it after, plus an explicit end. Everything
// about this file exists because of a specific bug on a real lock
// screen; the comments say which.

import {
  endLiveActivity,
  isLiveActivitySupported,
  startLiveActivity,
  updateLiveActivity,
  type SessionActivityState,
} from "../module/src";

export interface ReconcileInput extends SessionActivityState {
  sessionId: string;
  startedAtMs: number;
}

let started = false;
// Last state actually delivered, so an unchanged reconcile is free. The
// caller re-runs on every render of its screen; typing "225" used to be
// three ActivityKit writes for a state that had not moved.
let lastStateJson: string | null = null;
let currentSessionId: string | null = null;

// Sessions that have been explicitly ended. A reconcile for one of these
// must never run: a late update queued behind the end, or an effect
// re-firing during teardown, would re-create the activity from scratch.
// That is the "island still glowing after the workout" bug. Bounded so
// a long-lived JS process cannot grow it forever.
const endedSessionIds: string[] = [];
const ENDED_MEMORY = 8;

function markEnded(sessionId: string): void {
  if (endedSessionIds.includes(sessionId)) return;
  endedSessionIds.push(sessionId);
  if (endedSessionIds.length > ENDED_MEMORY) endedSessionIds.shift();
}

// Serializes every call. Two quick reconciles both saw started=false,
// both called start, and the native end-existing-first sweeps raced each
// other, leaving two cards stacked on the lock screen. Each call now
// waits for the previous one to settle before reading the flags.
let chain: Promise<void> = Promise.resolve();

export function reconcileLiveActivity(input: ReconcileInput): Promise<void> {
  chain = chain.then(() => doReconcile(input)).catch(() => undefined);
  return chain;
}

async function doReconcile(input: ReconcileInput): Promise<void> {
  if (!isLiveActivitySupported()) return;
  if (endedSessionIds.includes(input.sessionId)) return;
  const { sessionId, startedAtMs, ...state } = input;
  if (!started || currentSessionId !== sessionId) {
    const id = await startLiveActivity({ sessionId, startedAtMs }, state);
    if (id) {
      started = true;
      currentSessionId = sessionId;
      lastStateJson = JSON.stringify(state);
    }
    return;
  }
  const nextJson = JSON.stringify(state);
  if (nextJson === lastStateJson) return;
  // Record only once the native side has taken it. ActivityKit updates
  // are budget-limited and can be rejected; caching before the await
  // marked a failed write as delivered, and every later reconcile with
  // the same state was skipped, leaving the card stuck on stale data.
  await updateLiveActivity(state);
  lastStateJson = nextJson;
}

/**
 * End the activity. Await this before navigating away: fire-and-forget
 * races app suspension, and the end never lands.
 */
export function endLiveActivityCoordinator(sessionId?: string): Promise<void> {
  lastStateJson = null;
  // No `started` guard. The flag is in memory and resets on every JS
  // reload (relaunch, OTA apply) while iOS keeps the activity alive
  // across restarts. The native end resolves any OS-alive activity
  // itself and no-ops when there is none, so always call it.
  //
  // Tombstone synchronously, before joining the chain: a reconcile queued
  // between now and the chained end must already see the session as dead.
  if (sessionId) markEnded(sessionId);
  chain = chain
    .then(async () => {
      if (currentSessionId) markEnded(currentSessionId);
      started = false;
      currentSessionId = null;
      await endLiveActivity();
    })
    .catch(() => undefined);
  return chain;
}
