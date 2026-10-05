# Dockset comparison — implementation audit

Reference: [Dockset manual](https://dockset.app/manual), reviewed 2026-10-04.
This checklist describes the unreleased branch. It is not a claim of complete
feature parity, a macOS port, or successful hardware/provider acceptance.

| Dockset area | Perch implementation | Remaining difference |
|---|---|---|
| Dock layouts | Four edges, compact/wide tiles, scale, scrolling, spacers, reorder, auto-hide, monitor selection, themes | One surface on one selected monitor; exact macOS styling/animation differs |
| App/file/link tiles | Installed app picker and icons, local files/folders, HTTP(S) links, plugin pins | No macOS app badges, Finder tags, AirDrop or native Shortcuts integration |
| Running apps | Verified Hyprland window list/focus; optional compositor thumbnails; native minimize request | Capture needs live verification; Hyprland may ignore minimize; no app badge aggregation |
| Saved docks | 12 profiles, autosave, templates, manual/keyboard switching, JSON file/text backups | Focus-mode integration replaced by optional local weekday/time schedules; no app-window layout restoration |
| Calendar | Local/synced ICS agenda, recurrence, meeting countdown and Join | Account synchronization is external; no Apple Calendar integration; complex recurrence reported partial |
| Reminders | Local named lists, add/complete/reopen/remove and undo | No Apple Reminders/cloud synchronization, due-date editor or notification scheduling |
| Hydration | Intervals, due Notch context, optional volume/history, daily totals, delete/undo | No system-notification prompt; no cloud health integration |
| Music | MPRIS playback/seek/player selection, covers, local synchronized lyrics and full reader | Depends on player capabilities; no lyrics subscription provider or audio visualizer |
| Files and clipboard | Reference shelf, drag/drop, previews, open/reveal, LocalSend, clipboard search/copy | Wayland app interoperability needs live testing; no automatic paste; deletion uses the system clipboard tool |
| Weather | City search, C/F units, hourly forecast, five locations including primary | Open-Meteo source; no Apple Weather attribution/service |
| Stats/storage | CPU/per-core, RAM, swap, pressure, load, uptime, root disk, bounded folder scan, home Trash | No GPU/process inspector or destructive cleanup; home Trash count excludes other volumes |
| AI allowance tiles | Codex and Claude usage sources | Dockset's Cursor/Gemini/Copilot/Grok/Antigravity quota adapters remain unimplemented |
| AI activity history | Bounded local Codex/Claude daily token charts with partial markers | No account-wide billing totals, Cursor/Gemini history or cost estimates |
| Stripe | Named accounts, independent revenue/net/MRR/ARR/ARPU tiles, comparisons and persistent subscription charts | No churn/LTV; complex subscriptions excluded; observations start locally |
| Paddle | Multiple accounts, independent net-revenue/MRR/ARR charts and prior-period comparisons | No expanded subscription/churn metrics |
| Shopify | Multiple stores, independent order-value/count/AOV tiles, store-local periods and comparisons | Same-organization app required; order totals differ from store analytics; comparison limited by 60-day access |
| Perch-specific tools | Timers, device controls, notifications, activities/agent requests and plugin cards | These remain native Perch features, with their existing live acceptance requirements |

## Verification boundary

Portable tests exercise real compiled helpers and production QML with host
stubs. They do not establish real compositor capture, hardware controls,
notification ownership, file dialogs or cloud-account correctness. See
[TESTING.md](TESTING.md), [DOCKS.md](DOCKS.md) and [BUSINESS.md](BUSINESS.md).

Before release, test four edges and scaling on Omarchy, hidden input regions,
focus release after launching, display hotplug, preview capture, native dialogs,
profile persistence across a shell restart and real read-only provider accounts.
Do not remove the preview label based on portable checks alone.
