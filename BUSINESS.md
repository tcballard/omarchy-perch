# Read-only business metrics

Add **Business** in the Dock editor. Select a private JSON credential file,
a period (1, 7 or 30 days), and currency, then Connect. One connection is active
at a time. Refresh runs every five minutes only while its card/tile is visible.
Disconnect stops new reads. Errors preserve the last successful report with its
age; they never replace a failed report with an invented zero.

Create the credential file outside the repository and make it private with
`chmod 600 /absolute/path/to/perch-business.json`. It must be owned by your user,
a regular file and at most 8 KiB. The UI stores its path; keys stay in the helper
and travel to curl through stdin, never command-line arguments or dock backups.
No transactions or customer data are written back to a provider.

## Stripe

```json
{"provider":"stripe","apiKey":"rk_live_REPLACE_ME"}
```

Use a restricted key with read access to Balance transactions and Subscriptions
and any referenced resources Stripe requires. Both test and live restricted keys
are supported. Requests pin API version `2025-06-30.basil`.

Revenue sums charge/payment/refund-related balance transactions; Net after fees
sums their net values. Transfers, payouts and disputes are excluded. Reports use
UTC dates and one selected currency without currency conversion. MRR/ARR/ARPU
are estimates from fixed, licensed active/past-due subscription items. Trials and
metered items are excluded. Discounts, tiered prices or incomplete item pages
hide subscription estimates instead of displaying a knowingly partial estimate.
Pagination is limited to 2,000 transactions and 2,000 subscriptions; exceeding a
limit fails the report. These definitions may differ from Stripe Dashboard.

## Paddle Billing

```json
{"provider":"paddle","apiKey":"pdl_live_apikey_REPLACE_ME"}
```

Use a key with read permission for the Metrics API. Sandbox keys are recognized
by their prefix. Revenue and MRR come from Paddle's metrics endpoints; ARR is
12 × the latest MRR. The provider's reported currency is used. A mismatched
currency or invalid series fails the report.

## Shopify

```json
{"provider":"shopify","shop":"YOUR-STORE.myshopify.com","clientId":"REPLACE_ME","clientSecret":"REPLACE_ME"}
```

Use a Dev Dashboard app belonging to the same organization as the shop, installed
with `read_orders`. This uses Shopify's client-credentials grant; it is not a
public-app OAuth flow. Tokens are requested by the backend and kept in memory.
GraphQL requests use version `2026-07` and the shop's currency.

Sales and average order value use current order totals, exclude test/cancelled
orders, and use UTC creation dates. This is an order-total view, not a cash-flow
or Shopify Analytics accounting reconciliation. Reports stop at 10,000 orders
or the time budget and fail rather than showing an incomplete total.

## Sources and limits

- [Stripe balance transactions](https://docs.stripe.com/api/balance_transactions/list)
- [Stripe subscriptions](https://docs.stripe.com/api/subscriptions/list)
- [Paddle revenue](https://developer.paddle.com/api-reference/metrics/get-metrics-revenue)
- [Paddle MRR](https://developer.paddle.com/api-reference/metrics/get-metrics-monthly-recurring-revenue)
- [Shopify client credentials](https://shopify.dev/docs/apps/build/authentication-authorization/client-credentials-grant)
- [Shopify orders](https://shopify.dev/docs/api/admin-graphql/2026-07/queries/orders)

Requests have bounded time/size limits, fixed provider hosts, HTTPS-only transport
and no redirect following. Supported currency exponents are explicitly listed in
the backend; unsupported currencies fail clearly. Fixture tests cover metrics,
private-file rules and request transport. Real account acceptance is outstanding.
