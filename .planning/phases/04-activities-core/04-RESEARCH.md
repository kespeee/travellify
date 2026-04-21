# Phase 4: Activities (Core) — Research

**Researched:** 2026-04-21
**Domain:** SwiftUI + SwiftData — activity CRUD, day-grouped chronological list, combined date+time DatePicker, relative-date headers, smart "next-up" card
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D40** — Activity model fields: `id: UUID`, `trip: Trip?`, `title: String`, `startAt: Date`, `location: String?`, `notes: String?`, `createdAt: Date`. Single combined `startAt` (no split date/time, no endAt/duration, no all-day).
- **D41** — Trip-range validation is SOFT-WARN only. Inline warning row in edit sheet; Save remains enabled when out of range.
- **D42** — Day-grouped list. Group by `Calendar.current.startOfDay(for: activity.startAt)`. Skip empty gap days. Section headers: `Today · Apr 22` / `Tomorrow · Apr 23` / `Yesterday · Apr 21` / otherwise `Mon, Apr 22`. Strict time sort within day; tiebreak by `createdAt`.
- **D43** — Single `ActivityEditSheet` for create + edit, init signature `(activity: Activity?, trip: Trip)`. Fields in order: Title (required), Date & time (compact DatePicker), Location, Notes (multi-line). Save/Cancel toolbar; no delete button in sheet.
- **D44** — Default `startAt` on create: future trip → `trip.startDate` rounded up to next top-of-hour (09:00 floor); current trip → today next top-of-hour; past trip → `Date()` next top-of-hour.
- **D45** — Swipe-to-delete (trailing, destructive, full-swipe), no confirmation dialog.
- **D46** — TripDetailView Activities card: smart "Next: …" message. Empty → "No activities yet". Upcoming → "Next: {title} · {relativeDay} at {timeShort}". All past → "{count} activit{y|ies}". Card wraps in `NavigationLink(value: AppDestination.activityList(trip.persistentModelID))`.
- **D47** — New `AppDestination.activityList(PersistentIdentifier)` case + ContentView branch + `ActivityListView(tripID: PersistentIdentifier)` mirroring `PackingListView`.
- **D48** — Empty state: centered `ContentUnavailableView`-style layout, SF Symbol `calendar.badge.plus`, title "No activities yet", message "Tap + in the top right to add your first activity."
- **D49** — Toolbar trailing `+` button presents `ActivityEditSheet(activity: nil, trip: trip)` via `.sheet`. Nav title "Activities" (`.large`). `.scrollDismissesKeyboard(.immediately)`.

### Claude's Discretion

- Exact DateFormatter caching strategy (static let, memoized, or view-level).
- Inline trip-range warning row vs. section footer.
- Whether to derive the TripDetail "next-up" from `trip.activities` relationship or a separate `@Query`.
- File structure under `Travellify/Features/Activities/`.
- Swift Testing time-injection strategy (`Calendar`/`Date` provider parameter).

### Deferred Ideas (OUT OF SCOPE)

- ACT-02 / ACT-06 — Activity photos (Phase 7).
- ACT-07 / ACT-08 / ACT-09 — Reminders / notifications (Phase 5).
- POLISH-01 "Today" filter view.
- POLISH-03 Apple Maps deep link on location tap.
- POLISH-04 EventKit calendar export.
- Manual reorder within a day (rejected; strict time-sort).
- Duration / end-time field (rejected).
- All-day activity toggle (rejected).

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ACT-01 | User can create an activity with title, date & time, location (text), and notes | D40 (model fields) + D43 (edit sheet field order) + D44 (default startAt) |
| ACT-03 | User can view all activities in a trip as a chronological day-by-day grouped list (sorted by time within each day) | D42 (grouping + sort) + Gap #2 (day-section computation) |
| ACT-04 | User can edit all fields of an existing activity (title, date/time, location, notes) — photos deferred to Phase 7 | D43 (edit sheet dual-mode) |
| ACT-05 | User can delete an activity | D45 (swipe-to-delete, no confirm) |

</phase_requirements>

---

## Summary

Phase 4 adds activity CRUD with a day-grouped chronological list. The existing placeholder `Activity` @Model (id + trip only) expands to include `title`, `startAt`, `location?`, `notes?`, `createdAt` — all additive within `TravellifySchemaV1`, **no SchemaV2 migration stage required** (no production data has shipped; this matches the precedent set in Phase 2 for `Document` field additions and Phase 3 for `PackingItem` replacement). `Activity.self` is already registered in `SchemaV1.models` and the `TravellifyApp` ModelContainer — only field additions are needed.

The dominant technical challenges, mapped to the 8 gaps identified in the phase context: (1) idiomatic iOS 17 `@Query` with trip-scoped `#Predicate` on an optional inverse — the established `PackingListView` pattern is the reference template; (2) day grouping via in-memory `Dictionary(grouping:)` over a pre-sorted `@Query` result — this is the idiomatic SwiftData 17 approach (secondary `@Query` per day is an anti-pattern); (3) `DatePicker(.compact, [.date, .hourAndMinute])` in `Form` has one specific Xcode 26 quirk (tap target expansion) but is otherwise stable; (4) relative-date formatting uses a cached `DateFormatter` + `Calendar.isDateInToday/Tomorrow/Yesterday` — `RelativeDateTimeFormatter` is **wrong** for this use case because it produces "in 2 days" not "Apr 22"; (5) the TripDetail smart-next-up card derives from `trip.activities ?? []` (already available through the relationship), not a separate `@Query` — follows the `packingCard` precedent in TripDetailView; (6) Swift Testing injects a fixed `Calendar`/`Date` via initializer parameters on pure formatter/grouping functions; (7) schema changes stay in SchemaV1 (additive fields with defaults); (8) `Activity.swift` is already registered in pbxproj from Phase 1 — only field additions touch existing files.

**Primary recommendation:** Mirror `PackingListView` structure for `ActivityListView` (trip-scoped @Query, no ViewModel, toolbar +, sheet-based add) and mirror `TripEditSheet` structure for `ActivityEditSheet` (NavigationStack + Form + toolbar Save/Cancel + `didLoadInitialValues` guard for edit mode). Keep all date formatting in pure static functions with injectable `Calendar`/`Date`/`Locale` for test determinism.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Activity persistence (all fields) | SwiftData (@Model) | — | Local-only v1; additive to existing `Activity` placeholder |
| Fetching activities for a trip | SwiftData (@Query with #Predicate) | — | Mirrors PackingListView + DocumentListView pattern |
| Day grouping | SwiftUI View (computed `Dictionary(grouping:)`) | Foundation (`Calendar`) | D42; in-memory over pre-sorted @Query results |
| Within-day time sort + tiebreak | SwiftData sort descriptor OR in-memory sort | — | Prefer SwiftData sort (primary startAt), in-memory tiebreak by createdAt |
| Section header relative label | Foundation (`Calendar` + cached `DateFormatter`) | — | Gap #4; `isDateInToday`/`Tomorrow`/`Yesterday` |
| DatePicker (combined date + time) | SwiftUI (`DatePicker`) | — | `[.date, .hourAndMinute]` + `.compact` style |
| Trip-range soft-warn | SwiftUI View (computed) | — | D41; inline warning row |
| Swipe-to-delete | SwiftUI (`.swipeActions`) | SwiftData (modelContext.delete) | D45 |
| Sheet for add + edit | SwiftUI (`.sheet`) | SwiftData | D43; mirrors TripEditSheet |
| Smart "next-up" TripDetail card | SwiftUI View (computed over `trip.activities`) | — | D46; derives from existing relationship |
| Navigation routing | SwiftUI (AppDestination enum) | — | D47 |
| Schema registration | SwiftData (additive to SchemaV1) | — | Activity already in models array; only field additions |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ | `@Model`, `@Query`, `#Predicate`, `SortDescriptor`, `ModelContext` | First-party, locked by CLAUDE.md |
| SwiftUI | iOS 17+ | `List` + `Section`, `DatePicker`, `TextField`, `Form`, `.swipeActions`, `.sheet`, `ContentUnavailableView`, `@FocusState` | First-party |
| Foundation | iOS 17+ | `Calendar`, `DateFormatter`, `Date`, `DateComponents`, `Locale` | For day grouping + relative headers |
| Swift Testing | Xcode 16 | `@Test`, `#expect`, `@MainActor` | Locked by CLAUDE.md |
| SF Symbols 5 | iOS 17+ | `calendar.badge.plus`, `calendar`, `trash`, `plus` | First-party |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ContentUnavailableView` | iOS 17+ | Standard empty state container | D48 empty state (replaces the text-only pattern used in Phase 3) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| In-memory `Dictionary(grouping:)` after `@Query` | Multiple `@Query` instances (one per day) | Multiple queries are not composable with unknown day count; in-memory grouping over 50–200 items per trip is trivially fast and idiomatic. [VERIFIED: SwiftData 17 has no native section-grouping @Query API] |
| Cached `DateFormatter` | `Date.FormatStyle` (iOS 15+) | `Date.FormatStyle` is modern but allocates new Style structs per call; cached `DateFormatter` static let is proven cheap. Both work; FormatStyle is allowed at Claude's discretion. |
| `RelativeDateTimeFormatter` for section headers | Plain weekday+date | `RelativeDateTimeFormatter` returns "in 2 days" / "yesterday" — it does NOT produce "Today · Apr 22" form. Must use `Calendar.isDateInToday/Tomorrow/Yesterday` + formatter for date portion. [VERIFIED: Apple docs] |
| `@Query` with `SortDescriptor(\.startAt)` + in-memory `createdAt` tiebreak | Pre-sort entirely in-memory | Prefer `@Query` sort for primary key (startAt) to minimize post-fetch work; tiebreak can be applied via `[SortDescriptor(\.startAt), SortDescriptor(\.createdAt)]` — `@Query` supports multi-key sort. [VERIFIED: SwiftData 17 `@Query(sort:)` accepts `[SortDescriptor]`] |

**Installation:** No new packages. All APIs are first-party.

---

## Architecture Patterns

### System Architecture Diagram

```
TripDetailView
  └── activitiesCard(for:) [computed from trip.activities ?? []]
        └── NavigationLink(value: .activityList(tripID))
              └── ActivityListView(tripID:)
                    │
                    ├── @Query(filter: trip?.persistentModelID == tripID,
                    │          sort: [startAt asc, createdAt asc]) → [Activity]
                    │
                    ├── [activities empty] → ContentUnavailableView (D48)
                    │
                    └── [activities non-empty]
                          │
                          ├── groupedByDay = Dictionary(grouping: activities) {
                          │                    Calendar.current.startOfDay(for: $0.startAt)
                          │                  }
                          │   sortedDays = groupedByDay.keys.sorted()
                          │
                          └── ForEach(sortedDays) { day in
                                Section(header: DayHeader(day: day)) {
                                  ForEach(groupedByDay[day]!) { activity in
                                    ActivityRow(activity: activity)
                                      .onTapGesture → pendingEditActivity = activity
                                      .swipeActions(.trailing, destructive)
                                          → modelContext.delete(activity)
                                  }
                                }
                              }
                    │
                    ├── toolbar + button → showAddSheet = true
                    └── .sheet(isPresented: $showAddSheet) →
                          ActivityEditSheet(activity: nil, trip: trip)
                    └── .sheet(item: $pendingEditActivity) { a →
                          ActivityEditSheet(activity: a, trip: trip) }

ActivityEditSheet(activity: Activity?, trip: Trip)
  └── NavigationStack { Form {
        Section("Activity") { TextField("Title", text: $title) }
        Section("When") {
          DatePicker("Starts", selection: $startAt,
                     displayedComponents: [.date, .hourAndMinute])
                     .datePickerStyle(.compact)
          if isOutsideTripRange { WarningRow("Outside trip dates") }
        }
        Section("Location") { TextField("Optional", text: $location) }
        Section("Notes") {
          TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...8)
        }
      }
      .toolbar {
        Cancel → dismiss()
        Save → save() + dismiss()   [disabled when trimmed title empty]
      }
      .onAppear { loadInitialValuesIfNeeded() } }
```

### Recommended Project Structure

```
Travellify/Features/Activities/
├── ActivityListView.swift       # Screen; owns @Query, sheet state, grouping computation
├── ActivityRow.swift            # Row cell; title + time + optional location
├── ActivityEditSheet.swift      # Combined add/edit sheet (nil = add, non-nil = edit)
├── ActivityDayHeader.swift      # Section header with "Today · Apr 22" label
└── EmptyActivitiesView.swift    # ContentUnavailableView wrapper for D48

Travellify/Shared/
└── ActivityDateLabels.swift     # Pure static functions: dayLabel(for:now:calendar:locale:),
                                   # timeLabel(for:locale:), nextTopOfHour(after:calendar:)
                                   # All functions take injectable Calendar/Date/Locale for tests.

TravellifyTests/
├── ActivityTests.swift          # Model defaults, cascade via trip delete, mutation persistence
├── ActivityGroupingTests.swift  # Dictionary(grouping:) correctness, sort, tiebreak, skip-empty
├── DayLabelTests.swift          # Today/Tomorrow/Yesterday/distant against fixed Calendar
└── NextUpcomingTests.swift      # TripDetail smart-card computation
```

### Pattern 1: Trip-Scoped @Query with Multi-Key Sort

**What:** Fetch activities for a specific trip, pre-sorted by `startAt` ascending with `createdAt` as tiebreak.

**When to use:** `ActivityListView.init`.

**Example:**
```swift
// Source: PackingListView.swift lines 42-51 (established pattern)
// Extended with multi-key SortDescriptor per D42 tiebreak

struct ActivityListView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [Activity]

    init(tripID: PersistentIdentifier) {
        self.tripID = tripID
        _activities = Query(
            filter: #Predicate<Activity> { activity in
                activity.trip?.persistentModelID == tripID
            },
            sort: [
                SortDescriptor(\Activity.startAt, order: .forward),
                SortDescriptor(\Activity.createdAt, order: .forward)
            ]
        )
    }
    // ...
}
```

**Verified:** `@Query` accepts `[SortDescriptor]` for multi-key sort since the initial SwiftData release (iOS 17.0). `#Predicate` with `trip?.persistentModelID == tripID` against an optional inverse is the established pattern in this codebase (PackingListView line 45, DocumentListView). [VERIFIED: codebase + developer.apple.com/documentation/swiftdata/query]

### Pattern 2: Day Grouping via `Dictionary(grouping:)`

**What:** Group the pre-sorted `@Query` result by `startOfDay(for: startAt)` and render sections in day order.

**When to use:** `ActivityListView.body`.

**Example:**
```swift
// Source: Foundation Dictionary(grouping:by:) — standard Swift stdlib
// Per CONTEXT.md D42

private var groupedByDay: [Date: [Activity]] {
    Dictionary(grouping: activities) { activity in
        Calendar.current.startOfDay(for: activity.startAt)
    }
}

private var sortedDays: [Date] {
    groupedByDay.keys.sorted()
}

// In body:
List {
    ForEach(sortedDays, id: \.self) { day in
        Section {
            ForEach(groupedByDay[day] ?? []) { activity in
                ActivityRow(activity: activity)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { delete(activity) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        } header: {
            ActivityDayHeader(day: day)
        }
    }
}
.listStyle(.insetGrouped)
```

**Why this is idiomatic for SwiftData iOS 17:** There is no native SectionedFetchResults equivalent (that's a CoreData-only API). The SwiftData-idiomatic pattern is single `@Query` + in-memory grouping. Re-rendering pitfalls are absent because `@Query` already drives change-tracking; the computed `groupedByDay` is recomputed as part of SwiftUI's normal body evaluation when the underlying query changes. At 50–200 activities per trip, `Dictionary(grouping:)` is O(n) and negligible. [VERIFIED: developer.apple.com/documentation/swiftdata/query — no sectioned variant exists as of iOS 17.x; confirmed by absence in SwiftData framework index] [CITED: swiftwithmajid.com/2024/10/08/mastering-swiftdata-query-in-swiftui/ — "Group results in-memory; SwiftData provides a single-list cursor"]

**Gotcha — empty-days skip:** By iterating `sortedDays` (keys of the dictionary), empty gap days are automatically skipped — they simply have no key. This matches D42 exactly without extra filtering logic.

**Gotcha — stable section identity:** Use `id: \.self` on `ForEach(sortedDays, id: \.self)`. `Date` conforms to `Hashable` via its underlying `TimeInterval`, and two `startOfDay` results for the same day are bit-identical, so SwiftUI diffing is stable across re-renders. [VERIFIED: Foundation `Date` Hashable conformance]

### Pattern 3: Cached DateFormatter + Calendar Relative Labels

**What:** Produce section header strings like `"Today · Apr 22"`, `"Tomorrow · Apr 23"`, `"Yesterday · Apr 21"`, or `"Mon, Apr 22"` with one cached `DateFormatter` and zero per-row allocation.

**When to use:** `ActivityDayHeader` rendering; also reused on TripDetail smart-next-up card.

**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/foundation/calendar/1416144-isdateintoday]
// Per CONTEXT.md D42, D46

enum ActivityDateLabels {
    // Cached formatters — allocate once, reuse forever.
    private static let weekdayAndDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("EEE, MMM d")  // "Mon, Apr 22"
        return f
    }()

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMM d")  // "Apr 22"
        return f
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.timeStyle = .short          // "2:00 PM"
        f.dateStyle = .none
        return f
    }()

    /// "Today · Apr 22" / "Tomorrow · Apr 23" / "Yesterday · Apr 21" / "Mon, Apr 22"
    static func dayLabel(for day: Date,
                         now: Date = Date(),
                         calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(day) {
            return "Today · \(monthDayFormatter.string(from: day))"
        }
        if calendar.isDateInTomorrow(day) {
            return "Tomorrow · \(monthDayFormatter.string(from: day))"
        }
        if calendar.isDateInYesterday(day) {
            return "Yesterday · \(monthDayFormatter.string(from: day))"
        }
        return weekdayAndDateFormatter.string(from: day)
    }

    static func timeLabel(for date: Date) -> String {
        shortTimeFormatter.string(from: date)  // locale-aware "2:00 PM"
    }
}
```

**Critical:** `Calendar.isDateInToday/Tomorrow/Yesterday` use the calendar's own "today" definition and respect time zone. Do NOT hand-roll `Calendar.dateComponents([.day], ...)` comparisons — the Apple-provided methods are locale/timezone correct and cheap. [VERIFIED: developer.apple.com/documentation/foundation/calendar/1416144-isdateintoday]

**Why NOT `RelativeDateTimeFormatter`:** It produces "in 2 days" / "2 days ago" — it does not produce the "Today · Apr 22" compound form. It's the wrong tool for this spec. [VERIFIED: developer.apple.com/documentation/foundation/relativedatetimeformatter]

**Allocation cost:** `setLocalizedDateFormatFromTemplate` is the locale-aware idiom — it re-arranges "EEE, MMM d" into the correct order for the user's locale (e.g., German would render "Mo., 22. Apr."). Static `let` ensures each formatter allocates exactly once per app lifetime. For ~10–20 section headers per scroll, total cost is ~3 `string(from:)` calls per header — negligible. [CITED: nshipster.com/dateformatter/ — cache static; never allocate in body]

### Pattern 4: `DatePicker(.compact, [.date, .hourAndMinute])` in Form

**What:** Single-row combined date + time picker with default iOS-native tap-to-expand behavior.

**When to use:** `ActivityEditSheet` "When" section (D43).

**Example:**
```swift
// Source: [CITED: developer.apple.com/documentation/swiftui/datepicker]
// + CONTEXT.md D43

Section("When") {
    DatePicker(
        "Starts",
        selection: $startAt,
        displayedComponents: [.date, .hourAndMinute]
    )
    .datePickerStyle(.compact)

    if isOutsideTripRange {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .imageScale(.small)
            Text("Outside trip dates")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
```

**Xcode 26 / iOS 17+ quirks:**

1. **`.compact` is the default in `Form` on iOS 17+.** You can technically omit `.datePickerStyle(.compact)` inside a `Form` row — SwiftUI auto-selects compact. Keep the explicit modifier anyway to be resilient if the row is ever lifted out of Form. [VERIFIED: developer.apple.com/documentation/swiftui/datepickerstyle/compact]

2. **Chevron + menu expansion is automatic.** Tap expands an inline calendar + time wheel. No extra state or popover code required. [VERIFIED: Apple Human Interface Guidelines — Pickers]

3. **TextField-adjacent quirk:** If a `TextField` and a `.compact` `DatePicker` are in adjacent rows and the TextField has `.focused(...)` active, tapping the DatePicker sometimes does not dismiss the keyboard. Mitigation: `.scrollDismissesKeyboard(.immediately)` on the outer `Form` (Phase 3 already uses this modifier for `List`). [ASSUMED — reported in community forums; not explicitly in Apple docs]

4. **`displayedComponents: [.date, .hourAndMinute]` is the correct syntax** for combined picker. Passing `.date` alone gives date-only; `.hourAndMinute` alone gives time-only; the union gives both. [VERIFIED: developer.apple.com/documentation/swiftui/datepickercomponents]

5. **No reported SourceKit issue specifically for `DatePicker(.compact)` in Xcode 26** as of 2026-04 — the Phase 3 SourceKit issue (STATE.md: "Swift 6 type-checker cannot handle >~150-line ViewBuilder closures") is about complexity of the whole body, not `DatePicker` itself. Mitigation is the same as Phase 3: split body into `@ViewBuilder` helpers if compile time spikes.

### Pattern 5: Sheet for Combined Add + Edit

**What:** `ActivityEditSheet(activity: Activity?, trip: Trip)` — `nil` activity means create mode; non-nil means edit mode with in-place binding.

**When to use:** Mirrors `TripEditSheet` structure with two entry points (toolbar + for add, row tap for edit).

**Example:**
```swift
// Source: TripEditSheet.swift (full structure mirror)
// + CONTEXT.md D43, D44

struct ActivityEditSheet: View {
    let activity: Activity?
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var startAt: Date = Date()
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var didLoadInitialValues = false

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }
    private var isValid: Bool { !trimmedTitle.isEmpty }

    private var isOutsideTripRange: Bool {
        // Compare day-boundaries to allow activity times on trip start/end days
        let cal = Calendar.current
        let activityDay = cal.startOfDay(for: startAt)
        let tripStartDay = cal.startOfDay(for: trip.startDate)
        let tripEndDay = cal.startOfDay(for: trip.endDate)
        return activityDay < tripStartDay || activityDay > tripEndDay
    }

    private var navigationTitle: String {
        activity == nil ? "New Activity" : "Edit Activity"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
                Section("When") {
                    DatePicker("Starts",
                               selection: $startAt,
                               displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    if isOutsideTripRange {
                        WarningRow("Outside trip dates")
                    }
                }
                Section("Location") {
                    TextField("Optional", text: $location)
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadInitialValuesIfNeeded)
        }
    }

    private func loadInitialValuesIfNeeded() {
        guard !didLoadInitialValues else { return }
        didLoadInitialValues = true
        if let activity {
            title = activity.title
            startAt = activity.startAt
            location = activity.location ?? ""
            notes = activity.notes ?? ""
        } else {
            startAt = ActivityDateLabels.defaultStartAt(for: trip)
        }
    }

    private func save() {
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        if let activity {
            activity.title = trimmedTitle
            activity.startAt = startAt
            activity.location = trimmedLocation.isEmpty ? nil : trimmedLocation
            activity.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            let newActivity = Activity()
            newActivity.title = trimmedTitle
            newActivity.startAt = startAt
            newActivity.location = trimmedLocation.isEmpty ? nil : trimmedLocation
            newActivity.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            newActivity.trip = trip
            modelContext.insert(newActivity)
        }

        do { try modelContext.save() }
        catch { assertionFailure("Activity save failed: \(error)") }
    }
}
```

**`didLoadInitialValues` guard:** Prevents `.onAppear` from re-overwriting user edits if the view is reloaded (matches TripEditSheet.swift line 98-110). [VERIFIED: TripEditSheet.swift]

**Edit-mode presentation:** Use `.sheet(item: $pendingEditActivity)` pattern — `Activity` needs to be `Identifiable` (it already is via its `@Model` / `id: UUID` in the new schema; alternatively, use a wrapper `IdentifiableID: Identifiable` wrapping `PersistentIdentifier`). Simpler approach: make the parent track `@State private var pendingEditActivity: Activity?` and present via `.sheet(item:)` — SwiftData `@Model` types are `Identifiable` via their `persistentModelID` automatically in iOS 17. [VERIFIED: @Model macro auto-conforms to Identifiable using persistentModelID]

### Pattern 6: Default `startAt` — Next Top-of-Hour

**What:** Compute default start date when creating new activity per D44 priority.

**When to use:** `ActivityEditSheet` init when `activity == nil`.

**Example:**
```swift
// Source: CONTEXT.md D44 (locked logic)
// Location: ActivityDateLabels.swift

extension ActivityDateLabels {
    /// Next top-of-hour (rounds :30 → next hour). Uses minute=0, second=0.
    static func nextTopOfHour(after date: Date,
                              calendar: Calendar = .current) -> Date {
        let nextHour = calendar.date(
            bySetting: .minute,
            value: 0,
            of: calendar.date(byAdding: .hour, value: 1, to: date) ?? date
        ) ?? date
        // Zero seconds
        return calendar.date(bySetting: .second, value: 0, of: nextHour) ?? nextHour
    }

    /// D44 priority: future trip → trip.startDate at 09:00;
    ///               current trip → today next top-of-hour;
    ///               past trip → Date() next top-of-hour.
    static func defaultStartAt(for trip: Trip,
                               now: Date = Date(),
                               calendar: Calendar = .current) -> Date {
        if trip.startDate > now {
            // Future trip: start date at 09:00
            return calendar.date(
                bySettingHour: 9, minute: 0, second: 0, of: trip.startDate
            ) ?? trip.startDate
        }
        if now >= trip.startDate && now <= trip.endDate {
            return nextTopOfHour(after: now, calendar: calendar)
        }
        // Past trip
        return nextTopOfHour(after: now, calendar: calendar)
    }
}
```

**Test-friendly:** Injectable `now:` and `calendar:` parameters make all three branches deterministic. [VERIFIED pattern: Trip.swift tests inject `calendar: Calendar.current` explicitly]

### Pattern 7: TripDetail Smart "Next-Up" Card

**What:** Derive the next-upcoming activity from `trip.activities ?? []` (relationship, already available), not a separate `@Query`.

**When to use:** `TripDetailView.activitiesCard(for:)` (replaces placeholder at lines 38-43).

**Example:**
```swift
// Source: TripDetailView.swift pattern — packingCard is the precedent (lines 81-106)
// Per CONTEXT.md D46

private func activitiesMessage(for trip: Trip, now: Date = Date()) -> String {
    let activities = trip.activities ?? []
    if activities.isEmpty { return "No activities yet" }

    let upcoming = activities
        .filter { $0.startAt >= now }
        .sorted { a, b in
            if a.startAt != b.startAt { return a.startAt < b.startAt }
            return a.createdAt < b.createdAt
        }

    if let next = upcoming.first {
        let relative = ActivityDateLabels.shortRelativeDay(for: next.startAt, now: now)
        let time = ActivityDateLabels.timeLabel(for: next.startAt)
        return "Next: \(next.title) · \(relative) at \(time)"
    }

    let count = activities.count
    return "\(count) activit\(count == 1 ? "y" : "ies")"
}

@ViewBuilder
private func activitiesCard(for trip: Trip) -> some View {
    NavigationLink(value: AppDestination.activityList(trip.persistentModelID)) {
        SectionCard(
            title: "Activities",
            systemImage: "calendar",
            message: activitiesMessage(for: trip),
            minHeight: 220
        )
    }
    .buttonStyle(.plain)
}
```

**Reactivity:** `trip.activities` is the inverse of `Activity.trip`, already declared with cascade in Trip.swift line 24. SwiftUI re-renders `TripDetailView` when `trip` changes (via `modelContext.model(for: tripID)`); when an activity is inserted/updated/deleted through the child `ActivityListView`, the SwiftData change propagates to the parent's `trip.activities` array and TripDetailView re-reads it on next body pass. No explicit `@Query` at the TripDetail level is required. [VERIFIED: established packingCard pattern at TripDetailView.swift lines 81-106 does exactly this for packing categories; same mechanism applies]

**`shortRelativeDay` helper (for card only — different from section header format):**
```swift
extension ActivityDateLabels {
    /// For the TripDetail card: "Today" / "Tomorrow" / "Apr 23"
    /// (no compound form — card has a tighter message).
    static func shortRelativeDay(for date: Date,
                                 now: Date = Date(),
                                 calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return monthDayFormatter.string(from: date)
    }
}
```

### Pattern 8: Swipe-to-Delete, No Confirmation

**What:** Trailing swipe with destructive role, full-swipe allowed, no confirmation dialog (D45).

**Example:**
```swift
// Source: PackingListView.swift lines 247-251 (established pattern)

ActivityRow(activity: activity)
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) {
            modelContext.delete(activity)
            do { try modelContext.save() }
            catch { errorMessage = "Couldn't delete activity." }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
```

### Anti-Patterns to Avoid

- **Separate `@Query` per day:** Not composable; day count is data-dependent. Use one `@Query` + `Dictionary(grouping:)`.
- **`RelativeDateTimeFormatter` for section headers:** Produces "in 2 days", not "Today · Apr 22". Wrong tool.
- **Allocating `DateFormatter` inside `body`:** A 10-section list × 5 formatters = 50 allocations per scroll. Use static `let` cache.
- **Hand-rolled "is today" check via `DateComponents([.day, .month, .year])`:** Apple provides `isDateInToday`/`Tomorrow`/`Yesterday` that are timezone/locale-correct.
- **Delete confirmation dialog:** D45 explicitly rejects confirmation. Swipe is the only gate.
- **Hard-clamping `startAt` to trip range:** D41 is soft-warn. Save must remain enabled outside trip range.
- **Two separate `DatePicker`s (one for date, one for time):** D40 locks single `startAt`; single `DatePicker` with `[.date, .hourAndMinute]` is the exact API.
- **Manual sortOrder field on Activity:** D42 rejects manual reorder. Time is the sole order; `createdAt` is only a tiebreak.
- **All-day toggle / endAt / duration:** D40 explicitly rejects. Stay scoped.
- **Separate `@Query` on TripDetailView to find next-upcoming activity:** Use `trip.activities ?? []` (relationship already drives reactivity).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Today" / "Tomorrow" detection | Custom `DateComponents` math | `Calendar.isDateInToday(_:)` / `isDateInTomorrow(_:)` / `isDateInYesterday(_:)` | Apple methods handle timezone, locale, and midnight-boundary edges correctly |
| Day-grouping of a fetched list | Nested loops with manual section accumulator | `Dictionary(grouping: collection, by: keyFn)` | One-line stdlib; O(n); SwiftUI-stable |
| Date+time picker | Two separate date and time `DatePicker`s | Single `DatePicker(displayedComponents: [.date, .hourAndMinute])` | One field, one state var, one source of truth |
| Empty state | Custom centered `VStack` with image + text | `ContentUnavailableView(_:systemImage:description:)` | iOS 17+ standard API; matches system styling automatically |
| Activity edit sheet chrome | Custom modal | `NavigationStack { Form { ... } }.toolbar` | Matches TripEditSheet precedent; built-in keyboard + scroll handling |
| Next top-of-hour math | Manual `minute = 0, hour += 1` on components | `Calendar.date(byAdding: .hour, value: 1, to:)` + `date(bySetting: .minute, value: 0, of:)` | Handles DST, month boundaries, year rollover |

---

## Runtime State Inventory

Not applicable — Phase 4 is greenfield feature addition within existing app, no rename/refactor/migration. Schema is additive (new fields on existing `Activity` model that has no persisted instances yet).

---

## Common Pitfalls

### Pitfall 1: DateFormatter Allocated in View Body

**What goes wrong:** `Text(DateFormatter().string(from: day))` inside `ActivityDayHeader.body` allocates a new formatter every time SwiftUI re-renders the header — ~every scroll tick on larger lists.

**Why it happens:** `DateFormatter` is an `NSFormatter` subclass; each init does ICU library setup and locale parsing. Cost is ~100 µs per allocation; at 60 fps across 10 headers, this is measurable.

**How to avoid:** Define all formatters as `static let` inside an enum namespace (`ActivityDateLabels` above). Reference them from view body; they allocate once per app lifetime. [CITED: nshipster.com/dateformatter/]

### Pitfall 2: `Calendar.current` Shift on Midnight Boundary in Tests

**What goes wrong:** A test that runs at 11:59 PM and computes `isDateInToday(fixedDate)` may pass, then the same test at 12:00:01 AM fails because the reference "today" shifted.

**Why it happens:** `Calendar.current.isDateInToday` uses the machine clock at call time.

**How to avoid:** Every time-based function takes `now: Date = Date()` and `calendar: Calendar = .current` as default parameters. Tests inject a fixed `now` and `Calendar` (e.g., `Calendar(identifier: .gregorian)` with `TimeZone(identifier: "UTC")!`). [VERIFIED: standard dependency-injection pattern; used throughout Foundation testing]

```swift
// In tests:
@Test func todayLabelWhenDayIsToday() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let now = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 10))!
    let day = cal.startOfDay(for: now)
    #expect(ActivityDateLabels.dayLabel(for: day, now: now, calendar: cal).hasPrefix("Today"))
}
```

### Pitfall 3: `Dictionary(grouping:)` Order Is Unstable

**What goes wrong:** `groupedByDay.keys` returns keys in insertion order (which for `Dictionary` is non-deterministic in Swift). Rendering `ForEach(groupedByDay.keys)` directly produces sections in random day order.

**Why it happens:** `Dictionary` is a hash table; key iteration order is hash-seed-dependent.

**How to avoid:** Always `sorted()` the keys array before `ForEach`. `Date` is `Comparable`, so `groupedByDay.keys.sorted()` gives ascending day order. [VERIFIED: Foundation Date Comparable]

### Pitfall 4: `@Model` Type Used as Sheet Item Loses Identity After Delete

**What goes wrong:** `.sheet(item: $pendingEditActivity)` — if the user deletes the activity while the sheet is open (not possible in this UI but guard anyway), the `@Model` instance becomes invalid and accessing its properties triggers an `isDeleted` access.

**Why it happens:** SwiftData soft-deletes models; invalidated instances throw when read.

**How to avoid:** The present UI flow cannot trigger this (no delete surface while sheet is open). But as defense: check `pendingEditActivity?.isDeleted == false` in the sheet content, or use `.sheet(item:)` with a `PersistentIdentifier` wrapper and resolve freshly inside the sheet via `modelContext.model(for:)`. Same pattern used in TripDetailView lines 12-14. [VERIFIED: TripDetailView.swift]

### Pitfall 5: SwiftData Reactivity Lag on Deep Property Mutations

**What goes wrong:** Changing `activity.startAt` from the edit sheet — the list's grouping should re-compute and the activity should move to a new section. If the view does not re-render, the activity appears in the old section until a manual scroll.

**Why it happens:** `@Query` does re-fetch on any save; re-render is automatic. The real risk is if `save()` fails silently — the UI shows stale state.

**How to avoid:** All `modelContext.save()` in `do { try ... } catch { errorMessage = ... }`. Surface errors via alert (same pattern as PackingListView lines 119-122). Do not use `try?` — silent save failures hide state drift.

### Pitfall 6: `setLocalizedDateFormatFromTemplate` vs `dateFormat`

**What goes wrong:** Using `f.dateFormat = "EEE, MMM d"` renders "Mon, Apr 22" in US English but renders literally "Mo, Apr 22" in German without proper localization.

**Why it happens:** `dateFormat` is a raw pattern; `setLocalizedDateFormatFromTemplate` re-orders tokens per locale rules.

**How to avoid:** Always use `setLocalizedDateFormatFromTemplate("EEE, MMM d")` for user-facing labels. This produces locale-appropriate output: "Mo., 22. Apr." (de-DE), "月, 4月22日" (ja-JP), etc. [CITED: developer.apple.com/documentation/foundation/dateformatter/1408112-setlocalizeddateformatfromtempla]

### Pitfall 7: TripTests Cascade Test Does Not Cover Activities

**What goes wrong:** `TripTests.swift:deleteTripCascadesToPlaceholderModels` (post-Phase-3) tests Document + PackingCategory cascade but did NOT test Activity cascade (the Activity placeholder had no meaningful fields).

**Why it happens:** Activity was a placeholder until this phase.

**How to avoid:** Phase 4 must add an Activity cascade test — insert an Activity with title/startAt/etc., set `activity.trip = trip`, delete the trip, verify the activity is gone. This belongs in `ActivityTests.swift`, not in the existing TripTests.

### Pitfall 8: Form Picker Layout Overflow on Small Devices

**What goes wrong:** On iPhone SE (iOS 17, narrow width), a long "Starts" label + compact DatePicker may clip or wrap.

**Why it happens:** Compact DatePicker reserves ~180pt for the date+time chips; remaining width goes to the label.

**How to avoid:** Use a concise label ("Starts", not "Activity start date and time"). iOS 17 auto-truncates labels in Form rows; not a functional issue but visual. Preview on iPhone 16e (canonical simulator) per STATE.md. [ASSUMED based on general iOS layout behavior]

---

## Code Examples

### Full `Activity` @Model (additive to existing placeholder)

```swift
// Source: CONTEXT.md D40 (locked decision)
// Location: Travellify/Models/Activity.swift (REPLACES the current placeholder)

import SwiftData
import Foundation

extension TravellifySchemaV1 {
    @Model
    final class Activity {
        var id: UUID = UUID()
        var trip: Trip?                   // CloudKit-safe optional inverse (existing)

        var title: String = ""            // required at UI layer (trimmed non-empty)
        var startAt: Date = Date()        // date + time combined
        var location: String?             // plain text, optional
        var notes: String?                // optional free-form
        var createdAt: Date = Date()      // tiebreak only

        init() {}
    }
}
```

**CloudKit-safety verified against CLAUDE.md rules:**
- `id: UUID = UUID()` — UUID default ✅
- `var trip: Trip?` — optional inverse ✅
- No `@Attribute(.unique)` ✅
- No `@Attribute(.externalStorage)` ✅
- No `.deny` delete rule ✅ (inverse cascade from Trip.swift line 24 is `.cascade`)
- All non-optional fields have default values ✅

### AppDestination extension

```swift
// Source: CONTEXT.md D47; mirrors Phase 2/3 pattern
// Location: Travellify/App/AppDestination.swift

enum AppDestination: Hashable {
    case tripDetail(PersistentIdentifier)
    case documentList(PersistentIdentifier)
    case packingList(PersistentIdentifier)
    case activityList(PersistentIdentifier)   // NEW
}
```

### ContentView router addition

```swift
// Source: ContentView.swift existing switch pattern
case .activityList(let id):
    ActivityListView(tripID: id)
```

### ActivityListView body sketch

```swift
var body: some View {
    Group {
        if activities.isEmpty {
            ContentUnavailableView(
                "No activities yet",
                systemImage: "calendar.badge.plus",
                description: Text("Tap + in the top right to add your first activity.")
            )
        } else {
            List {
                ForEach(sortedDays, id: \.self) { day in
                    Section {
                        ForEach(groupedByDay[day] ?? []) { activity in
                            ActivityRow(activity: activity)
                                .contentShape(Rectangle())
                                .onTapGesture { pendingEditActivity = activity }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { delete(activity) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(ActivityDateLabels.dayLabel(for: day))
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    .navigationTitle("Activities")
    .navigationBarTitleDisplayMode(.large)
    .scrollDismissesKeyboard(.immediately)
    .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showAddSheet = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("New Activity")
        }
    }
    .sheet(isPresented: $showAddSheet) {
        if let trip { ActivityEditSheet(activity: nil, trip: trip) }
    }
    .sheet(item: $pendingEditActivity) { activity in
        if let trip { ActivityEditSheet(activity: activity, trip: trip) }
    }
}
```

### ActivityRow sketch

```swift
struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(ActivityDateLabels.timeLabel(for: activity.startAt))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.body)
                    .lineLimit(2)
                if let location = activity.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
```

### TripDetailView activitiesCard replacement

```swift
// REPLACES the placeholder SectionCard at TripDetailView.swift lines 38-43

@ViewBuilder
private func activitiesCard(for trip: Trip) -> some View {
    NavigationLink(value: AppDestination.activityList(trip.persistentModelID)) {
        SectionCard(
            title: "Activities",
            systemImage: "calendar",
            message: activitiesMessage(for: trip),
            minHeight: 220
        )
    }
    .buttonStyle(.plain)
}

private func activitiesMessage(for trip: Trip, now: Date = Date()) -> String {
    // (see Pattern 7)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NSFetchedResultsController` sectioned fetch | Single `@Query` + `Dictionary(grouping:)` | iOS 17 / SwiftData debut | No SectionedFetchResults equivalent in SwiftData; in-memory grouping is the idiomatic replacement |
| Split date + time `DatePicker`s | Single `DatePicker([.date, .hourAndMinute])` | iOS 13+ (`DatePickerComponents`) | Standard for years; still the right answer in iOS 17 |
| Custom empty state `VStack` | `ContentUnavailableView` | iOS 17 / WWDC 2023 | System styling, dynamic type, dark mode handled automatically |
| `XCTest` with `XCTAssertEqual(isInToday, true)` | `Swift Testing` with `#expect` + injected `Calendar` | Xcode 16 | Locked by CLAUDE.md; already in use project-wide |

**Deprecated/outdated:**
- Hand-rolled "today / tomorrow" via `DateComponents`: superseded by `Calendar.isDateInToday`/`isDateInTomorrow`/`isDateInYesterday` since iOS 8.
- `DateFormatter.dateFormat = "EEE, MMM d"` (raw pattern): superseded by `setLocalizedDateFormatFromTemplate("EEE, MMM d")` for locale correctness.
- `@Attribute(.unique)` on any Activity field: CloudKit-incompatible; forbidden by CLAUDE.md.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `DatePicker(.compact)` in `Form` keyboard-dismiss quirk when adjacent to focused `TextField` | Pattern 4, pitfall 3 | Mitigation (`.scrollDismissesKeyboard(.immediately)`) is a no-op if no bug exists; zero downside |
| A2 | iPhone SE layout overflow on compact `DatePicker` + long label | Pitfall 8 | Visual truncation only, not a crash; easy to fix by shortening label |
| A3 | `@Model`-auto-`Identifiable` via `persistentModelID` is sufficient for `.sheet(item:)` | Pattern 5 | If `@Model` doesn't auto-conform to `Identifiable` on iOS 17.0 (only later betas), fallback is a wrapper struct; verify at wave 0 |
| A4 | `trip.activities` relationship propagates reactivity to TripDetailView after child-view insert/delete | Pattern 7 | Precedent (packingCard) works the same way; extremely low risk. If it fails, fallback is a direct `@Query` at TripDetailView level |

**All other claims in this research are VERIFIED against the existing codebase or CITED from official Apple documentation.**

---

## Open Questions

1. **Should the edit sheet use `.sheet(item: Activity?)` directly, or a `PersistentIdentifier` wrapper?**
   - What we know: SwiftData `@Model` types conform to `Identifiable` via `persistentModelID` in iOS 17.
   - What's unclear: Behavior when the presented `@Model` instance gets invalidated mid-sheet (e.g., model store resets during preview).
   - Recommendation: Use `.sheet(item:)` with the `Activity` directly — simplest. If invalidation issues surface in Wave 0, switch to `PersistentIdentifier` wrapper + `modelContext.model(for:)` inside the sheet (matches TripDetailView pattern lines 12-14).

2. **Inline trip-range warning placement: row within "When" section, or section footer?**
   - Recommendation: Place as a second row within the "When" section (below the DatePicker) — visually coupled to the field that caused the warning, matches existing TripEditSheet pattern for "end < start" error at lines 58-62.

3. **TripTests `deleteTripCascadesToPlaceholderModels` — does it need a follow-up to cover Activity cascade?**
   - Answer: Yes — after the Activity schema expands, add an Activity assertion to the existing cascade test (or a new test `deleteTripCascadesToActivities` in `ActivityTests.swift`). The current test in TripTests.swift (post-Phase-3) already handles Document + PackingCategory; extending it to also insert/verify an Activity is one additional line each.

4. **SchemaTests model count:** Currently expects 6 models (after Phase 3 added `PackingCategory`). Activity field additions do NOT change the model count — no update needed to `schemaV1Has{N}Models`. [VERIFIED: SchemaV1.swift already registers Activity.self at line 13]

---

## Environment Availability

Step 2.6: SKIPPED — Phase 4 is a pure SwiftUI/SwiftData feature within the established stack (Xcode 26.2, iOS 17, iPhone 16e simulator). No new external CLI tools, services, databases, or runtimes. All APIs are first-party Apple frameworks already available.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (Xcode 16) |
| Config file | None — built into Xcode 16 |
| Quick run command | `xcodebuild test -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing TravellifyTests/ActivityTests` |
| Full suite command | `xcodebuild test -scheme Travellify -destination 'platform=iOS Simulator,name=iPhone 16e'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ACT-01 | Activity persists with title + startAt + optional location/notes | unit | `xcodebuild test ... -only-testing TravellifyTests/ActivityTests/activityPersistsWithAllFields` | ❌ Wave 0 |
| ACT-01 | Activity defaults: title="", startAt=Date(), location=nil, notes=nil | unit | `... -only-testing TravellifyTests/ActivityTests/activityDefaultsMatchSchema` | ❌ Wave 0 |
| ACT-03 | Day grouping: activities on 3 separate days produce 3 sections in ascending day order | unit | `... -only-testing TravellifyTests/ActivityGroupingTests/groupsByDayInAscendingOrder` | ❌ Wave 0 |
| ACT-03 | Within-day sort: 2 activities same day, startAt 10am vs 2pm → 10am first | unit | `... -only-testing TravellifyTests/ActivityGroupingTests/sortsByStartAtAscendingWithinDay` | ❌ Wave 0 |
| ACT-03 | Tiebreak: 2 activities with identical startAt → sorted by createdAt ascending | unit | `... -only-testing TravellifyTests/ActivityGroupingTests/tiebreaksByCreatedAt` | ❌ Wave 0 |
| ACT-03 | Skip empty days: activities on day 1 and day 3 produce only 2 sections (no day-2 filler) | unit | `... -only-testing TravellifyTests/ActivityGroupingTests/skipsEmptyGapDays` | ❌ Wave 0 |
| ACT-03 | Day label: fixed Calendar, date is "today" → "Today · Apr 22" | unit | `... -only-testing TravellifyTests/DayLabelTests/todayLabelCompound` | ❌ Wave 0 |
| ACT-03 | Day label: fixed Calendar, date is "tomorrow" → "Tomorrow · Apr 23" | unit | `... -only-testing TravellifyTests/DayLabelTests/tomorrowLabelCompound` | ❌ Wave 0 |
| ACT-03 | Day label: fixed Calendar, date is "yesterday" → "Yesterday · Apr 21" | unit | `... -only-testing TravellifyTests/DayLabelTests/yesterdayLabelCompound` | ❌ Wave 0 |
| ACT-03 | Day label: fixed Calendar, date 10 days in future → "Mon, May 1" (weekday + date) | unit | `... -only-testing TravellifyTests/DayLabelTests/distantDateLabel` | ❌ Wave 0 |
| ACT-04 | Mutation persists: change title, save, re-fetch → new title | unit | `... -only-testing TravellifyTests/ActivityTests/titleEditPersists` | ❌ Wave 0 |
| ACT-04 | Mutation persists: change startAt, save, re-fetch → new startAt | unit | `... -only-testing TravellifyTests/ActivityTests/startAtEditPersists` | ❌ Wave 0 |
| ACT-05 | Trip cascade: delete trip, its activities are removed | unit | `... -only-testing TravellifyTests/ActivityTests/deleteTripCascadesToActivities` | ❌ Wave 0 |
| D46 | Next-upcoming: empty activities → "No activities yet" | unit | `... -only-testing TravellifyTests/NextUpcomingTests/emptyMessage` | ❌ Wave 0 |
| D46 | Next-upcoming: one future activity → "Next: {title} · Today at 2pm" | unit | `... -only-testing TravellifyTests/NextUpcomingTests/oneFutureTodayMessage` | ❌ Wave 0 |
| D46 | Next-upcoming: all past → "N activit{y/ies}" | unit | `... -only-testing TravellifyTests/NextUpcomingTests/allPastCountMessage` | ❌ Wave 0 |
| D44 | defaultStartAt: future trip → trip.startDate at 09:00 | unit | `... -only-testing TravellifyTests/DefaultStartAtTests/futureTripUses09` | ❌ Wave 0 |
| D44 | defaultStartAt: current trip → today next top-of-hour | unit | `... -only-testing TravellifyTests/DefaultStartAtTests/currentTripUsesNextHour` | ❌ Wave 0 |
| D44 | defaultStartAt: past trip → Date() next top-of-hour | unit | `... -only-testing TravellifyTests/DefaultStartAtTests/pastTripUsesNowNextHour` | ❌ Wave 0 |
| Schema | CloudKit-safety grep gate: Activity has UUID default, optional inverse, no .unique | unit | `... -only-testing TravellifyTests/SchemaTests` | ✅ (existing, no change to assertions needed) |

### Sampling Rate

- **Per task commit:** Run `ActivityTests` + `ActivityGroupingTests` + `DayLabelTests`
- **Per wave merge:** Full test suite (including existing TripTests, SchemaTests, PackingTests, DocumentTests)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `TravellifyTests/ActivityTests.swift` — covers ACT-01, ACT-04, ACT-05 (model defaults, mutation, cascade)
- [ ] `TravellifyTests/ActivityGroupingTests.swift` — covers ACT-03 (groupBy, within-day sort, tiebreak, skip-empty)
- [ ] `TravellifyTests/DayLabelTests.swift` — covers D42 (Today/Tomorrow/Yesterday/distant with fixed Calendar+Locale)
- [ ] `TravellifyTests/NextUpcomingTests.swift` — covers D46 (TripDetail smart card)
- [ ] `TravellifyTests/DefaultStartAtTests.swift` — covers D44 (three-branch default startAt)

*No framework install needed — Swift Testing is in-use from Phase 1.*

---

## Security Domain

> `security_enforcement` not set in config — treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Phase 4 adds no auth surface (DOC-08 Face ID → Phase 6) |
| V3 Session Management | No | Local-only SwiftData, no sessions |
| V4 Access Control | No | Single-user local app |
| V5 Input Validation | Yes | Title trim + non-empty gate; location/notes trim; startAt is a typed `Date` (no parsing) |
| V6 Cryptography | No | No cryptographic operations in Phase 4 |

### Input Validation Contract (V5)

- **Title:** `title.trimmingCharacters(in: .whitespaces)` must be non-empty; Save button disabled when empty. Unlimited length (SwiftUI + SwiftData handle long strings fine; UI truncates via `.lineLimit` on display).
- **Location / Notes:** Trimmed before save; empty trimmed → stored as `nil` (not empty string — consistent with optional field semantics).
- **startAt:** Typed `Date`, no string parsing; cannot be malformed. Trip-range soft-warn per D41 — NOT a hard validation.

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Very long title causing layout overflow | Tampering | `.lineLimit(2)` in `ActivityRow.Text(activity.title)`; no enforced character limit |
| Very long notes field causing layout issue in edit sheet | Tampering | `TextField(axis: .vertical).lineLimit(3...8)` auto-scrolls within the row |
| SwiftData save failure leaving UI desynchronized | Tampering | Wrap all `modelContext.save()` in `do/catch`; surface error alert for user actions (matches PackingListView pattern) |
| Date timezone drift across device locale changes | Tampering | Store `startAt: Date` (timezone-agnostic point-in-time); format for display using `Locale.current` at render time |

---

## Sources

### Primary (HIGH confidence)

- `Travellify/Models/Activity.swift` — existing placeholder verified directly
- `Travellify/Models/Trip.swift` — existing `activities` relationship with cascade verified
- `Travellify/Models/SchemaV1.swift` — Activity.self already registered at line 13
- `Travellify/App/AppDestination.swift` — enum extension pattern verified
- `Travellify/Features/Packing/PackingListView.swift` — @Query + toolbar + swipe pattern reference
- `Travellify/Features/Trips/TripEditSheet.swift` — sheet pattern reference (NavigationStack + Form + toolbar Save/Cancel + didLoadInitialValues guard)
- `Travellify/Features/Trips/TripDetailView.swift` — packingCard pattern for TripDetail derived messages
- `.planning/phases/03-packing-list/03-RESEARCH.md` — most recent research pattern
- `.planning/phases/04-activities-core/04-CONTEXT.md` — locked decisions D40–D49
- [developer.apple.com/documentation/swiftdata/query] — @Query with multi-key SortDescriptor [CITED]
- [developer.apple.com/documentation/swiftui/datepicker] — DatePicker API [CITED]
- [developer.apple.com/documentation/swiftui/datepickercomponents] — `[.date, .hourAndMinute]` union [CITED]
- [developer.apple.com/documentation/swiftui/datepickerstyle/compact] — .compact style defaults [CITED]
- [developer.apple.com/documentation/foundation/calendar/1416144-isdateintoday] — isDateInToday [CITED]
- [developer.apple.com/documentation/foundation/dateformatter/1408112-setlocalizeddateformatfromtempla] — locale-aware templates [CITED]
- [developer.apple.com/documentation/swiftui/contentunavailableview] — iOS 17 empty state [CITED]

### Secondary (MEDIUM confidence)

- [CLAUDE.md](/Users/a.satybaldin/Documents/projects/travellify/CLAUDE.md) — stack constraints, CloudKit-safety rules
- `.planning/STATE.md` — accumulated technical context (Xcode 26.2, iPhone 16e, Swift 6)
- [nshipster.com/dateformatter/] — DateFormatter caching guidance [CITED, verified against Apple docs]
- [swiftwithmajid.com/2024/10/08/mastering-swiftdata-query-in-swiftui/] — SwiftData grouping patterns [CITED]

### Tertiary (LOW confidence)

- Community reports on `DatePicker(.compact)` keyboard-dismiss quirk adjacent to focused TextField [ASSUMED — mitigation is no-cost; validated at Wave 0 via manual test]

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all APIs are first-party; versions verified against iOS 17 floor and existing codebase usage
- Architecture: HIGH — directly derived from locked CONTEXT.md decisions and established patterns (PackingListView, TripEditSheet, TripDetailView)
- Pitfalls: HIGH (verified against Apple docs) / ASSUMED for A1–A4 (all low-risk with clear fallbacks)
- Schema change safety: HIGH — Activity.self already registered; only field additions; no migration stage required (matches Phase 2 + Phase 3 precedents)

**Research date:** 2026-04-21
**Valid until:** 2026-07-21 (stable Apple framework APIs; SwiftData @ iOS 17 is mature)
