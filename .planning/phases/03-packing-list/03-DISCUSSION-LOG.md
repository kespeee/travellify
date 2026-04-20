# Phase 3: Packing List - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `03-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-21
**Phase:** 03-packing-list
**Areas discussed:** Data model shape, Screen layout & progress, Swipe gesture split, Category & item CRUD UX

---

## Data model shape

### Category representation
| Option | Description | Selected |
|--------|-------------|----------|
| PackingCategory @Model with inverse | Separate @Model with id/name/trip + items relationship | ✓ |
| String field on PackingItem | `categoryName: String` on the item | |
| Enum of fixed categories | Predefined set; ruled out by PACK-05 | |

### Category ordering
| Option | Description | Selected |
|--------|-------------|----------|
| Creation order (sortOrder: Int) | Stable, opens door to later drag-reorder | ✓ |
| Alphabetical | Sort by name; surprises on rename | |
| Manual drag-reorder (v1) | Full reorder gesture in v1 | |

### Item ordering within a category
| Option | Description | Selected |
|--------|-------------|----------|
| Creation order (sortOrder: Int) | Stable, matches category ordering | ✓ |
| Alphabetical | Items jump around when renamed | |
| Unchecked first, then checked | Couples sort to check state | |

### Cascade on trip delete
| Option | Description | Selected |
|--------|-------------|----------|
| `@Relationship(deleteRule: .cascade)` | SwiftData handles cleanup | ✓ |
| Manual cleanup in TripListView | Only needed with filesystem side-effects | |

---

## Screen layout & progress

### Primary screen structure
| Option | Description | Selected |
|--------|-------------|----------|
| Single List with Section per category | All items on one screen, grouped | ✓ |
| Categories screen + drill-down | Two-level navigation | |

### Progress indicator location
| Option | Description | Selected |
|--------|-------------|----------|
| Inline header row at top, scrolls away | Simple, no sticky complexity | ✓ |
| Sticky header pinned to nav bar area | Always visible but custom logic | |
| Nav bar subtitle / title | Native, always visible but small | |

### Progress visual
| Option | Description | Selected |
|--------|-------------|----------|
| Text + thin ProgressView bar | Quick visual read | ✓ |
| Text only | Minimal | |
| Percentage ring | Heavier, Fitness-app feel | |

### Per-category progress indicator
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, 'X/Y' on right of section header | Useful pre-departure scan | ✓ |
| No, only trip-level | Simpler, less noise | |

---

## Swipe gesture split

### Check-off swipe edge
| Option | Description | Selected |
|--------|-------------|----------|
| Leading edge (swipe right) | Matches Mail 'Mark as Read' | ✓ |
| Trailing edge (swipe left) | Matches Reminders completion swipe | |

### Delete gesture placement
| Option | Description | Selected |
|--------|-------------|----------|
| Trailing swipe (red Destructive) | Standard iOS; no hidden actions | ✓ |
| Long-press context menu only | Mirrors Phase 2 Documents (D15) | |
| Both: trailing swipe AND context menu | Redundant for v1 | |

### Visual state for checked item
| Option | Description | Selected |
|--------|-------------|----------|
| Strikethrough + dimmed (.secondary) | Matches Reminders; stays in place | ✓ |
| Checkmark icon + full opacity | Subtler, less obvious at a glance | |
| Move to 'Packed' subsection at bottom | Rows jump on interaction | |

### Check-off feedback
| Option | Description | Selected |
|--------|-------------|----------|
| Light haptic on check, none on uncheck | Asymmetric, matches Reminders | |
| No haptic | Visual only | |
| Haptic on check AND uncheck | Symmetric feedback | ✓ |

---

## Category & item CRUD UX

### Adding an item
| Option | Description | Selected |
|--------|-------------|----------|
| Inline 'Add item' row at bottom of each section | Autofocus + stay-focused; fast multi-add | ✓ |
| '+' in toolbar → sheet | Extra tap per item | |
| '+' in each section header → inline TextField | Adds chrome per section | |

### Editing an item name
| Option | Description | Selected |
|--------|-------------|----------|
| Tap row → sheet with name + category picker | Simple, handles both in one place | |
| Long-press context menu → Rename / Move to… | Slower; menu grows with categories | |
| Inline edit: tap to rename, move via drag | Polished but adds implementation complexity | ✓ |

### Inline rename mechanic (follow-up)
| Option | Description | Selected |
|--------|-------------|----------|
| Double-tap to enter rename mode | Clear separation from swipe | |
| Single tap anywhere on row | Risks accidental rename | ✓ |
| Tap pencil icon on trailing | Adds chrome per row | |

### Drag scope (follow-up)
| Option | Description | Selected |
|--------|-------------|----------|
| Cross-category move only (no intra-category reorder) | Tight scope; sortOrder rewrite only on cross | ✓ |
| Both: cross-category move AND intra-category reorder | Full `.onMove`; revises creation-order decision | |

### Adding a category
| Option | Description | Selected |
|--------|-------------|----------|
| 'Add category' row at bottom of the list | Predictable; matches inline item adds | ✓ |
| Toolbar 'Categories' button → manage sheet | Hides simple add behind toolbar | |
| '+' in nav toolbar with type picker | Clutters primary action | |

### Category section header: rename/delete
| Option | Description | Selected |
|--------|-------------|----------|
| Long-press section header → context menu | Consistent with Phase 2 D15 | ✓ |
| Trailing ellipsis button in header | Adds chrome to every section | |
| Manage-categories sheet | Defers all to separate screen | |

### Deleting a non-empty category
| Option | Description | Selected |
|--------|-------------|----------|
| Cascade delete with item-count confirm dialog | Uses the chosen .cascade relationship | ✓ |
| Block delete if non-empty | Friction-heavy | |
| Move items to 'Uncategorized' catch-all | Conflicts with user-created-only model | |

---

## Claude's Discretion

- Exact spacing, font sizes, SF Symbol variants.
- Internal file layout under `Travellify/Features/Packing/`.
- `@FocusState` implementation for inline add/rename TextFields.
- Keyboard-return behavior on the add-item TextField (prefer insert-and-continue per D30).

## Deferred Ideas

- Intra-category drag-reorder (v1 out of scope; D21/D32).
- "Uncategorized" catch-all category (rejected D36).
- Trip templates / copy-from-past-trip lists (PROJECT.md out-of-scope).
- Stored aggregate counts (rejected D37; revisit if profiling demands it).
- Per-item notes, quantity, weight (not in PACK-01..07).
- Pin / flag swipe actions (not in scope).
