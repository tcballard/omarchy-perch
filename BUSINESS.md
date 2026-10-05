# Business accounts and metric tiles

Open a Business card and choose **Accounts**. Name the business, choose a colour
and provider, then choose credential storage:

- **Secret Service keyring** uses `secret-tool` from libsecret and an unlocked
  Secret Service implementation. Perch never silently falls back to another
  storage method. Keyring protection follows that implementation's configuration.
- **Private local file** stores credentials in Perch's state directory with
  owner-only permissions. It is not encrypted. This option is explicit.

**Enter credentials and connect** opens a separate native `zenity` dialog, with
masked key/secret fields. The Rust helper reads the dialog output, checks the
provider's read-only report permissions, and only then saves the account. Keys
never enter QML, process arguments, shell preferences or dock backups. Cancellation
or a failed check does not replace an existing account.

Up to 12 named accounts are supported. Existing private JSON files can be imported
without rewriting them. Use **Test** after import to verify access. Rename or
recolour accounts with **Edit**. **Disconnect** removes Perch's credential reference
or stored credential and its local history; imported source files are preserved.
Revoke the key/app at the provider if you also want to invalidate it there.

## Configure each tile

Choose **Use** beside an account, then open **Tile** to select the metric, period,
Stripe currency/time zone, and chart visibility. Add more using **Dock editor →
Library → Another business metric**. Up to eight tiles can share or use different
accounts, including two views of the same provider. Tile configuration belongs to
the dock profile; account connections remain global on this computer.

Identical account/period/currency/zone requests share a five-minute cache. A single
worker queues requests, limiting simultaneous provider traffic. Only visible
cards/tiles request refreshes. Errors retain the previous report with its update
time; changing the account or reporting parameters clears the old report.

## Periods and comparisons

Choose Today, Last 7 days, Month to date or Last 30 days. Periods include the
current, incomplete day. Stripe defaults to your computer's IANA time zone;
you can select a zone such as `Europe/London`. Shopify uses its reported store
zone and currency. Paddle uses UTC and its reported balance currency.

Stripe revenue and Shopify order comparisons cover the preceding equal number
of calendar days, ending at the same local clock time. Month-to-date compares
against the preceding equal-length span, not the entire previous month. DST is
applied at each boundary. Exact date ranges appear beneath the chart. Paddle
provides daily values, so its previous comparison includes those complete UTC
days; the current day may be incomplete. A zero or absent baseline never produces
an invented percentage.

Shopify's standard order access covers the last 60 days. If a month-end comparison
would exceed it, Perch displays current-period data and marks the comparison
unavailable. It does not show a knowingly incomplete previous total.

## Stripe

Create a restricted key (`rk_live_` or `rk_test_`) with read access to Balance and
Subscriptions and any referenced resources Stripe requires. Perch pins API
version `2025-06-30.basil`. Live/test prefixes label the account appropriately.

- Revenue sums charge/payment/refund-related balance transactions before fees.
- Net after fees sums those transactions' net values. Transfers, payouts and
  disputes are excluded. Collected tax is included; currencies are kept separate.
- MRR/ARR/ARPU estimate fixed, licensed active/past-due subscription items. Trials
  and metered items are excluded. Discounts, tiered prices or incomplete item
  pages make subscription estimates unavailable rather than partial.
- Paying subscribers counts customers with positive estimated MRR.

Revenue/net charts use provider transaction dates in the selected zone.
Subscription charts use Perch's persistent daily observations: the latest
successful refresh each day per currency and time zone. They start with the first
successful visible-tile refresh, survive shell restarts, and do not backfill.
Missing days and unsupported calculations remain blank. Previous subscription
values use the last observation on the previous end date and are labelled as
such, rather than pretending to be an exact historical intraday measurement.

History retains the latest 400 daily observations per account across its currencies
and zones. Disconnect removes it. Pagination is limited to 2,000 transactions
across both periods and 2,000 subscriptions; exceeding either fails the report.
Definitions may differ from Stripe Dashboard.

## Paddle Billing

Use a live/sandbox Billing API key with `metrics.read`. Paddle Classic is unsupported.
Net revenue and its chart use Paddle's metrics endpoint; MRR and its chart use the
provider's recurring-revenue series. ARR is 12 × MRR. The MRR/ARR headline is the
latest reported value in the period, not a sum of daily MRR.

Paddle net revenue is after tax/fees but before refunds/chargebacks. Results use
the provider's balance currency. Mismatched currencies fail clearly.

## Shopify

Install a Dev Dashboard app belonging to the same organization as your store,
with `read_orders`. Enter the `myshopify.com` domain, Client ID and Client secret
in the native dialog. This is a client-credentials connection for your own store,
not public-app OAuth. Tokens stay in helper memory; GraphQL uses version `2026-07`.

Order value/count/AOV use current order totals after returns/discounts, including
tax, shipping and unpaid orders; test/cancelled orders are excluded. With no orders,
AOV is unavailable. Edits affect the original order's date. These are order totals,
not cash flow or Shopify Analytics reconciliation. Reports stop at 10,000 orders
across both periods or their time budget and fail rather than showing partial totals.

## Existing connections and portability

An enabled legacy single-account connection is imported into the account registry
and assigned to the primary Business tile when the manager first loads. Its
currency, period and UTC behavior are preserved. The original file is not modified.
If import or preference saving fails, the old configuration remains available;
open Accounts to retry/import explicitly.

Exported docks contain tile settings and opaque account references, not connection
paths, credentials or history. On another computer, choose local accounts for the
imported tiles. No API keys are imported from a dock backup.

## Validation and sources

Portable fixtures cover account isolation, masked-dialog/keyring transport,
private-file permissions, cancellation, HTTP failures, history persistence,
comparison math, DST, migration and production QML. No real accounts or live
Secret Service/Omarchy session have been used for acceptance. Validate native
focus/dialog behavior and reconcile real reports before treating this as released.

Requests use fixed provider hosts, HTTPS without redirects, and bounded time/size.
Supported currency exponents remain explicit; unsupported currencies fail clearly.
HTTP authentication, permission and rate-limit failures have distinct messages.

- [Stripe transactions](https://docs.stripe.com/api/balance_transactions/list)
- [Stripe subscriptions](https://docs.stripe.com/api/subscriptions/list)
- [Paddle revenue](https://developer.paddle.com/api-reference/metrics/get-metrics-revenue)
- [Paddle MRR](https://developer.paddle.com/api-reference/metrics/get-metrics-monthly-recurring-revenue)
- [Shopify client credentials](https://shopify.dev/docs/apps/build/authentication-authorization/client-credentials-grant)
- [Shopify shop time zone](https://shopify.dev/docs/api/admin-graphql/2026-07/objects/Shop)
- [Shopify orders](https://shopify.dev/docs/api/admin-graphql/2026-07/queries/orders)
- [libsecret CLI implementation](https://github.com/GNOME/libsecret/blob/master/tool/secret-tool.c)
- [Zenity forms options](https://github.com/GNOME/zenity/blob/master/src/option.c)
