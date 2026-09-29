# Native Plugin Perch cards (v1)

A selected installed plugin can provide a native card inside Perch. The provider
owns its state, polling and actions; Omarchy owns installation, enablement and
permissions. Perch renders bounded plain-text data with its existing QML controls.
It never imports another plugin's QML, executes a supplied command or follows a
supplied URL. This contract does not move arbitrary bar widgets out of the bar.

Click a pinned plugin to open its card. **Refresh** reads the provider's current
snapshot; **Open** launches its full panel. A plugin without this optional
contract shows an unavailable-card message and retains the Open fallback.
Hover does not invoke plugins. No new background polling is added.

## Provider IPC

Expose methods on an `IpcHandler` whose target is your exact installed plugin ID:

```qml
function perchCard(): string { return JSON.stringify(snapshot()) }
function perchAction(request: string): string { /* validate, dispatch, return JSON */ }
```

`perchCard` must be read-only, fast and use existing service state. JSON example:

```json
{
  "version": 1,
  "revision": "r42",
  "title": "RSS Feed",
  "status": "ready",
  "summary": "2 unread",
  "actions": [{"id": "refresh", "label": "Refresh feeds"}],
  "rows": [{"id": "headline-1", "title": "Example headline", "detail": "Example feed",
    "action": {"id": "open:0", "label": "Read article"}}]
}
```

Limits: 32 KiB response, eight rows, four global actions, one action per row.
Title/summary/row-title/detail/action-label limits are 100/240/180/240/40 characters.
Status is `ready`, `empty`, `loading`, `error` or `offline`. Revision, row and
action IDs are 1–160 ASCII letters/digits/dot/underscore/colon/hyphen, starting
with a letter or digit. Row IDs and action IDs are unique within their category.
Unknown properties are discarded. All content is displayed as plain text.

An action request is `{"version":1,"revision":"r42","action":"open:0"}`.
Perch rechecks that the plugin is enabled, reads a fresh snapshot, and requires
the revision and advertised action to match. The provider **must check both
again** at execution time; the state may change between IPC calls. Return
`{"ok":true}` only after accepting/completing the operation, otherwise
`{"ok":false}`. Never treat incoming action IDs as shell text or URLs.

Only explicitly clicked actions are sent. An unknown revision/action is rejected.
After success Perch reads again. If that read fails it reports that the action
completed, so the user is not invited to repeat a possibly successful action.
Navigation/close increments a generation; late responses cannot replace a newer
selection. A pending read is bounded and finishes without updating a closed card.

Providers must not add privileged actions on the assumption that the caller is
Perch: the local IPC target is callable by other local clients too. V1 is intended
for ordinary plugin actions such as refresh/open. Agent approval transport is a
separate contract and is not implemented by this API.

The paired RSS Feed change is the reference provider (`PerchCard.js` and its
existing `Service.qml`). It resolves article IDs against current service data,
validates the revision, and opens only the provider-owned HTTP(S) article URL.
