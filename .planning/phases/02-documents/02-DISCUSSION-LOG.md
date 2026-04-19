# Phase 2 Discussion Log

**Date:** 2026-04-19
**Mode:** discuss (interactive gray-area walkthrough)

## Gray Areas Surfaced

Eight gray areas identified from REQUIREMENTS (DOC-01..07), CLAUDE.md tech notes, and Phase 1 context:

| # | Area | User chose |
|---|------|------------|
| 1 | Document model shape & file storage | default (D10) |
| 2 | Import entry point UX | **discussed** |
| 3 | Multi-page scan handling | default (D12) |
| 4 | Post-import naming flow | default (D13) |
| 5 | Viewer technology | **discussed** |
| 6 | Navigation from TripDetail | default (D17) |
| 7 | Delete & rename UX | **discussed** |
| 8 | Concurrency & file-write strategy | default (D18) |

## Discussion 1 — Import entry point UX

- **"+" button behavior:** Menu with 3 items (Scan / Photos / Files). Locked as D11.
- **Empty state:** text-only copy pointing to "+" toolbar. No inline CTAs. User diverged from recommended "single primary CTA" — keeps empty state calm.
- **Permissions:** lazy — OS prompts on first use. No pre-flight explainer.
- **File types:** PDF + common images (`.pdf`, `.image`).

## Discussion 2 — Viewer technology

- **Presentation:** `.fullScreenCover`. Pushed views and sheets rejected.
- **PDF renderer:** PDFKit `PDFView` via `UIViewRepresentable`.
- **Image zoom:** SwiftUI `ScrollView` + `Image` + `MagnificationGesture` (native, iOS 17+).
- **Chrome:** minimal top bar — X + title only. No share, no overflow, no bottom toolbar.

All locked as D14.

## Discussion 3 — Delete & rename UX

- **Delete trigger:** long-press context menu only. **User diverged from recommended swipe-to-delete** — explicitly wanted parity between delete and rename actions under a single context-menu surface.
- **Rename trigger:** same long-press context menu (user note: *"Same, long press with context menu where delete and rename should be"*).
- **Rename input:** `.alert` with `TextField` (default — user didn't diverge).
- **File cleanup:** explicit in delete action; trip cascade removes `<tripUUID>/` folder post-save.
- **Confirm dialog copy:** name + finality warning ("Delete '<name>'? This removes the file from your device and cannot be undone.").

All locked as D15 + D16.

## Defaults Accepted (no discussion)

- **D10 Model shape:** `displayName`, `fileRelativePath`, `kind` (pdf/image), `importedAt`. Files in `Application Support/Documents/<tripUUID>/<docUUID>.<ext>`. No `@Attribute(.externalStorage)`.
- **D12 Multi-page scan:** one Document, one combined PDF (PDFKit assembly).
- **D13 Auto-naming:** `"Scan YYYY-MM-DD"` / `"Photo YYYY-MM-DD"` / source filename.
- **D17 TripDetail wiring:** card shows count + latest; tap pushes `.documentList(tripID)` via extended `AppDestination`.
- **D18 Concurrency:** file copy on background Task, main-context insert. No `@ModelActor` in v1.

## Divergences from Recommended Defaults

1. **Empty state:** user chose text-only instead of single primary CTA. Rationale: respects the "calm" tone of Phase 1 empty state.
2. **Delete gesture:** user chose context menu only instead of swipe + context menu. Rationale: one action surface for both rename and delete reduces UI inventory.

## Scope Creep Deferred

None raised.

## Next Steps Communicated

1. `/gsd-ui-phase 2` — build `02-UI-SPEC.md` from D11/D13/D14/D15/D17.
2. `/gsd-plan-phase 2` — research first (six Open Questions), then plan.
