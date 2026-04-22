---
status: complete
phase: 05-notifications
source:
  - 05-01-SUMMARY.md
  - 05-02-SUMMARY.md
  - 05-03-SUMMARY.md
  - 05-04-SUMMARY.md
started: 2026-04-22T21:58:07Z
updated: 2026-04-22T22:45:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Reminder Section visible in ActivityEditSheet
expected: Open any trip → Activities → tap "+" to add an activity. After the Notes section, a "Reminder" section appears with an off-by-default "Remind me" toggle.
result: pass

### 2. First-ever toggle triggers iOS system permission prompt
expected: Fresh install (or permission still .notDetermined). Flip the Remind toggle ON → the native iOS permission dialog appears immediately. Tap Allow → toggle stays on; Don't Allow → toggle flips back off.
result: pass
note: 2026-04-22 — custom priming sheet removed (commit 4b08141); test redefined to native-only flow.

### 3. Permission granted → picker appears with 4 presets
expected: After granting notification permission, the toggle stays on and a lead-time picker appears showing exactly 4 options: 15 min, 1 hour, 3 hours, 1 day. Default selection is "1 hour".
result: pass

### 4. Save activity schedules a notification
expected: Set startAt to ~2 minutes from now, enable reminder with lead time 15 min (or pick a lead so fireDate is within a minute). Save activity. Lock device or background app. At the computed fireDate (startAt − leadMinutes), a local notification is delivered with title = activity title and body = "<trip name> · <time> · <location>" (location omitted when empty).
result: pass

### 5. Tap notification deep-links to activity list
expected: Tap the delivered notification. App opens (cold or warm) and navigates directly to the Activities list for that trip.
result: pass

### 6. Editing startAt reschedules the notification
expected: Open an activity with an enabled reminder, change startAt to a later time, save. The previously-pending notification is cancelled and a new one is scheduled for the new fireDate. (Verify by enabling Console/notifications or by rescheduling to ~1 minute out and waiting.)
result: pass

### 7. Toggling reminder off cancels the pending notification
expected: Open an activity that has a scheduled reminder, flip the Remind toggle OFF, save. The pending notification is cancelled — it will NOT fire at the originally scheduled fireDate.
result: pass

### 8. Deleting activity cancels its pending notification
expected: With a reminder scheduled on an activity, delete that activity from the Activities list. The pending notification is cancelled and will not fire.
result: pass

### 9. Deleting trip cancels all its reminders
expected: With multiple activities under a trip having reminders enabled, delete the trip. All pending notifications for that trip's activities are cancelled.
result: pass

### 10. Denied permission surfaces tappable "Notifications are off" alert
expected: In denied state, tapping Remind toggle ON pops a native iOS alert titled "Notifications are off" with "Enable them in Settings to get activity reminders." body and Open Settings / Cancel buttons. Open Settings jumps to iOS Settings for the app; Cancel dismisses and toggle stays off.
result: pass
note: 2026-04-22 — replaced persistent disabled-row + separate Open Settings button with tappable alert (commit e6a95cc). Single interaction point, matches iOS conventions.

## Summary

total: 10
passed: 10
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
