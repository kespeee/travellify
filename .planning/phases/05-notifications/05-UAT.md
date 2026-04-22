---
status: testing
phase: 05-notifications
source:
  - 05-01-SUMMARY.md
  - 05-02-SUMMARY.md
  - 05-03-SUMMARY.md
  - 05-04-SUMMARY.md
started: 2026-04-22T21:58:07Z
updated: 2026-04-22T21:59:00Z
---

## Current Test

number: 2
name: First-ever toggle shows priming sheet
expected: |
  With a fresh install (or first time ever enabling a reminder), flip the Remind toggle ON. A priming sheet appears first (bell icon, title, "Enable reminders" / "Not now" buttons) — BEFORE the iOS system permission dialog. Tapping "Enable reminders" then triggers the native iOS permission prompt.
awaiting: user response

## Tests

### 1. Reminder Section visible in ActivityEditSheet
expected: Open any trip → Activities → tap "+" to add an activity. After the Notes section, a "Reminder" section appears with an off-by-default "Remind me" toggle.
result: pass

### 2. First-ever toggle shows priming sheet
expected: With a fresh install (or first time ever enabling a reminder), flip the Remind toggle ON. A priming sheet appears first (bell icon, title, "Enable reminders" / "Not now" buttons) — BEFORE the iOS system permission dialog. Tapping "Enable reminders" then triggers the native iOS permission prompt.
result: [pending]

### 3. Permission granted → picker appears with 4 presets
expected: After granting notification permission, the toggle stays on and a lead-time picker appears showing exactly 4 options: 15 min, 1 hour, 3 hours, 1 day. Default selection is "1 hour".
result: [pending]

### 4. Save activity schedules a notification
expected: Set startAt to ~2 minutes from now, enable reminder with lead time 15 min (or pick a lead so fireDate is within a minute). Save activity. Lock device or background app. At the computed fireDate (startAt − leadMinutes), a local notification is delivered with title = activity title and body = "<trip name> · <time> · <location>" (location omitted when empty).
result: [pending]

### 5. Tap notification deep-links to activity list
expected: Tap the delivered notification. App opens (cold or warm) and navigates directly to the Activities list for that trip.
result: [pending]

### 6. Editing startAt reschedules the notification
expected: Open an activity with an enabled reminder, change startAt to a later time, save. The previously-pending notification is cancelled and a new one is scheduled for the new fireDate. (Verify by enabling Console/notifications or by rescheduling to ~1 minute out and waiting.)
result: [pending]

### 7. Toggling reminder off cancels the pending notification
expected: Open an activity that has a scheduled reminder, flip the Remind toggle OFF, save. The pending notification is cancelled — it will NOT fire at the originally scheduled fireDate.
result: [pending]

### 8. Deleting activity cancels its pending notification
expected: With a reminder scheduled on an activity, delete that activity from the Activities list. The pending notification is cancelled and will not fire.
result: [pending]

### 9. Deleting trip cancels all its reminders
expected: With multiple activities under a trip having reminders enabled, delete the trip. All pending notifications for that trip's activities are cancelled.
result: [pending]

### 10. Denied permission shows Open Settings row
expected: If notification permission is denied (either decline the system prompt, or deny in Settings), the Remind toggle becomes disabled. A row appears with "Notifications disabled." text and an "Open Settings" button that jumps to the app's iOS Settings page. Returning to the app with permission now granted re-enables the toggle.
result: [pending]

## Summary

total: 10
passed: 0
issues: 0
pending: 10
skipped: 0

## Gaps

[none yet]
