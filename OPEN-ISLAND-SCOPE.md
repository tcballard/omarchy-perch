# Perch: full Open Island scope and native Plugin Perch

Tom's direction, 29 September 2026: use **everything Open Island offers** as
the comparison baseline, including its complete desktop experience. The native
Plugin Perch drawer is additional scope. Agent cards alone do not complete it.

Source snapshot: [Open Island b50f87a](https://github.com/Octane0411/open-vibe-island/tree/b50f87aa7d58af1478837d48909eb68baa37f9b9).
Inspected README, docs/product.md, docs/notch-surface-model.md, docs/roadmap.md,
docs/ssh-setup.md, docs/watch-notification-design.md, SettingsView.swift,
AppearanceSettingsPane.swift, SessionState.swift and TerminalJumpTargetResolver.swift.
This is a source-based comparison, not a claim that either app was tested live.
README and implementation supersede older product/roadmap descriptions when they
disagree (for example Warp and the available languages).

**Status:** Built means present in the stacked Perch candidate, still subject to
desktop acceptance. Partial means related functionality exists but parity is not
complete. Outstanding remains in scope. Platform work needs an Omarchy-native
implementation or an explicit user decision; it is not silently dropped.

## Presentation and interaction

| Capability | Perch status | Work/acceptance needed |
|---|---|---|
| Ambient collapsed notch / top bar | Built | Idle, running, attention and completion visual review on XPS |
| Manual expanded session list | Partial | Expandable detail rows and richer session presentation |
| Dedicated approval surface | Outstanding | Request details, allow/deny, pending/expired/resolved states |
| Dedicated question surface | Outstanding | Choices and free-text answer round-trip |
| Dedicated completion surface | Outstanding | Task summary, dismissal and return to session |
| Automatic event-to-surface routing | Partial | Dedicated surfaces, queue arbitration and suppression |
| Content-derived panel height | Partial | Activity currently uses bounded item count; measure content across all cards |
| Hover entry, pointer leave and temporary surface timeout | Partial | Separate auto-open timeout/first-hover semantics from manual browsing |
| Keep open until a decision | Outstanding | Pending approval/question lifecycle, no accidental dismissal |
| Suppress notifications for frontmost session | Outstanding | Match target identity to focused window/session |
| Completion reply | Outstanding | Provider-specific supported reply transport |
| Animations and responsive interaction | Partial | Measure real compositor behaviour, reduced motion, scale and interruption |
| Built-in and external display positioning | Built | Hotplug, fractional scale and focused/pinned display validation |
| Appearance profiles and live preview | Partial | Perch has placement and modes; configurable compact slots/labels/list details remain |
| Configurable notification sounds and mute | Partial | Timer sound exists; event sound selection, preview and mute remain |
| Haptic feedback | Platform work | Determine supported Linux hardware feedback; no fake equivalent |
| Launch at login | Platform equivalent | Omarchy enables/loads the plugin; verify restart/disable lifecycle |
| Dock/menu-bar app visibility | Platform equivalent | Omarchy plugin presentation and discoverability, not macOS Dock APIs |
| Localisation | Outstanding | English, Simplified Chinese and Traditional Chinese strings/settings |
| Keyboard shortcuts | Partial | Perch toggle and navigation exist; upstream Shortcuts page is currently a placeholder |
| Advanced/Lab settings | Track upstream | Upstream Lab page is currently a placeholder, not delivered functionality |

## Sessions, actions and integrations

| Capability | Perch status | Work/acceptance needed |
|---|---|---|
| Stable session identity/project labels | Partial | Hook session IDs are hashed; richer metadata and lifecycle remain |
| Attention queue/count | Built | Multiple simultaneous requests, exact selection and resolved-request removal |
| Running/completed/waiting/error phases | Partial | Canonical reducer, tool summaries and explicit ended/disconnected states |
| Automatic transcript session discovery | Outstanding | Bounded provider readers, no broad private file scanning |
| Restore sessions across restart | Outstanding | Versioned durable store, TTL and liveness reconciliation |
| Process/session liveness | Outstanding | Correlate PID identity, exit/restart, detached/desktop/remote sessions |
| Permission decisions | Outstanding | Authenticated request ownership, expiry, allow/deny round-trip, fail-open transport |
| Question answering | Outstanding | Provider capability-specific responses and cancellation |
| Agent usage dashboard | Outstanding | Codex/Claude local usage sources, freshness and unavailable states |
| Claude status-line bridge | Outstanding | Opt-in installation preserving custom status lines |
| Hook setup/removal | Partial | Claude/Codex reversible installers exist; provider coverage/health/recovery remain |
| Claude Code CLI | Partial | Generic status/attention hooks; discovery, usage and real decisions remain |
| Claude desktop | Platform work | Identify supported Linux entry point and honest lifecycle/focus support |
| Codex CLI | Partial | Current completion notifier only; full session/turn/tool lifecycle remains |
| Codex desktop/app-server | Platform work | Supported Linux host/transport, lifecycle and conversation targeting |
| OpenCode | Outstanding | Extension, lifecycle, permission and question integration |
| Cursor | Outstanding | Hooks, workspace sessions and IDE return |
| Gemini CLI | Outstanding | Native hook lifecycle and event normalization |
| Grok Build | Outstanding | Camel-case payload adapter and managed installation |
| Kimi CLI | Outstanding | TOML hook installer and provider lifecycle |
| Qoder | Outstanding | Managed hook configuration and lifecycle |
| Qwen Code | Outstanding | Managed hook configuration and lifecycle |
| Factory | Outstanding | Managed hook configuration and lifecycle |
| CodeBuddy | Outstanding | Managed hook configuration and lifecycle |
| Pi | Outstanding | Extension, lifecycle and heartbeat |
| Oh My Pi | Outstanding | Its event aliases/extension and lifecycle |
| SSH sessions | Outstanding | Explicit secure tunnel/setup, remote identity, disconnect behaviour; upstream precise return remains limited |
| Watch/mobile notification relay | Platform work | Inspect upstream transport/client maturity, then choose a Linux-compatible companion path; remains tracked |

## Return to work

| Capability | Perch status | Work/acceptance needed |
|---|---|---|
| Hyprland window return | Built | Existing address check, focus release, explicit failure; verify on XPS |
| Ghostty session targeting | Outstanding | Supported Linux window/tab targeting; no AppleScript |
| WezTerm | Outstanding | Pane ID and owning-window targeting |
| tmux | Outstanding | Server/session/window/pane identity, detached sessions |
| Zellij | Outstanding | Session/tab/pane targeting |
| VS Code / Insiders | Outstanding | Exact workspace using supported CLI |
| Cursor / Windsurf / Trae / Zed | Outstanding | Provider-specific workspace/terminal return |
| JetBrains family | Outstanding | Workspace/project and launcher mapping |
| Warp | Platform work | Linux-supported precision path; do not copy macOS accessibility assumptions |
| Terminal.app / iTerm2 / cmux / Kaku / Conductor | Platform work | Track each platform-only target explicitly; map user outcome to supported Linux terminal/app where available |
| Failure and stale target handling | Partial | Window checks exist; pane reuse, identity mismatch and closed workspace cases remain |

## Setup, distribution and quality

| Capability | Perch status | Work/acceptance needed |
|---|---|---|
| Native local-first runtime | Built | QML in Omarchy, local bounded helpers; preserve no account/telemetry requirement |
| Fail-open agent hooks | Built for current hooks | Prove this for every added provider and response transport |
| First-run discovery/guidance | Partial | Setup/health page exists; guided dependency/provider flow remains |
| Integration health and repair | Partial | Diagnose stale hooks, changed paths/config and unsupported versions |
| Placement diagnostics | Partial | User-readable current display/scale/edge and fallback reason |
| About/version information | Partial | Clear installed build and compatibility information |
| Automatic update | Platform equivalent | Omarchy plugin update lifecycle; candidate/stable compatibility gates |
| Signing/notarized DMG | Platform equivalent | Reproducible source/package and Omarchy marketplace validation |
| Debug surface harness | Partial | Production QML fictional fixtures exist; add each new event surface |
| Sustained low idle resource use | Live gate | Record actual idle/active helper count, CPU and frame responsiveness |

## Additional Perch scope

| Capability | Status | Next gate |
|---|---|---|
| Pin/reorder installed plugins | Built | Live launcher handoff and persistence |
| Native plugin drawer | Built in current candidate | Versioned data-only native renderer, explicit actions; real host acceptance |
| First partner: RSS Feed | Paired candidate | Snapshot/unread/headlines, refresh and read action through existing service |
| More native plugin integrations | Outstanding | Add partners against the versioned contract; no arbitrary QML imports |
| Compact partner status | Outstanding | Define bounded visibility-driven freshness policy before adding background sampling |
| Arbitrary bar-widget relocation into drawer | Host/API work | Omarchy must retain widget/service ownership; native cards do not relocate arbitrary widgets |
| Existing media/files/clipboard/timers/calendar/devices/notifications | Preserve | Regression and live checks in TESTING.md |

## Delivery sequence

1. Native plugin drawer contract, real RSS partner, failure handling and regression evidence.
2. Content-sized panels and separate completion/approval/question surfaces with explicit pending behaviour.
3. Durable session model, liveness, discovery and supported Codex/Claude lifecycle/usage sources.
4. Real approval/question transport and precise terminal/IDE targeting.
5. Additional providers, SSH/companion paths, localisation and remaining settings/distribution equivalents.

This order sequences the work; it does not remove later rows from the target.
Do not claim full parity while outstanding rows remain. For each row, record a
PR and portable evidence, then separately record real desktop acceptance.
