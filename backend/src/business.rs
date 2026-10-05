//! Read-only, bounded business metrics. Credentials never enter QML or argv.
use crate::core::*;
use chrono::{Duration, Utc};
use serde_json::{json, Value};
use std::{fs, os::unix::fs::MetadataExt, path::Path, time::Instant};

fn quoted(s: &str) -> String {
    format!(
        "\"{}\"",
        s.replace('\\', "\\\\")
            .replace('"', "\\\"")
            .replace('\n', "\\n")
            .replace('\r', "\\r")
    )
}
fn secret(s: &str) -> Result<&str> {
    if s.is_empty() || s.len() > 4096 || s.chars().any(char::is_control) {
        return err("Credential is missing or invalid");
    }
    Ok(s)
}
fn fetch(url: &str, headers: &[String], body: Option<&Value>) -> Result<Value> {
    let form = url.ends_with("/admin/oauth/access_token");
    let mut config = format!("url = {}\n", quoted(url));
    for header in headers {
        config.push_str(&format!("header = {}\n", quoted(header)));
    }
    if let Some(body) = body {
        if form {
            config.push_str("header = \"Content-Type: application/x-www-form-urlencoded\"\n");
            for field in ["grant_type", "client_id", "client_secret"] {
                config.push_str(&format!(
                    "data-urlencode = {}\n",
                    quoted(&format!("{field}={}", s(body, field)))
                ));
            }
        } else {
            config.push_str(&format!(
                "header = \"Content-Type: application/json\"\ndata = {}\n",
                quoted(&string_json(body))
            ));
        }
    }
    let bytes = run_bytes(
        &[
            "curl",
            "--disable",
            "--config",
            "-",
            "--silent",
            "--proto",
            "=https",
            "--max-time",
            "7",
            "--max-filesize",
            "1048576",
            "--write-out",
            "\n%{http_code}",
        ],
        8.0,
        1048576,
        Some(config.as_bytes()),
    )
    .map_err(|_| {
        "Provider request failed. Check the read-only credentials, permissions and connection."
    })?;
    let bytes = bytes.trim_ascii_end();
    let split = bytes
        .iter()
        .rposition(|b| *b == b'\n')
        .ok_or("Provider response status unavailable")?;
    let status = std::str::from_utf8(&bytes[split + 1..]).unwrap_or("");
    match status {
        "200"=>serde_json::from_slice(&bytes[..split]).map_err(|_| "Provider returned an invalid response".into()),
        "401"=>err("Credentials rejected or expired; reconnect this account"),
        "403"=>err("Permission denied. Stripe: Balance and Subscriptions read; Paddle: metrics.read; Shopify: installed read_orders scope"),
        "429"=>err("Provider rate limit reached; wait before refreshing"),
        _=>err("Provider request failed; service unavailable or unsupported request. Last successful values are retained."),
    }
}
pub fn load_credentials(path: &Path) -> Result<Value> {
    let meta = fs::symlink_metadata(path)?;
    if !meta.is_file() || meta.uid() != uid() || meta.mode() & 0o077 != 0 {
        return err("Choose an owned, private credential file (chmod 600), not a symlink");
    }
    let bytes = read(path, 8192, false)?;
    let v: Value =
        serde_json::from_slice(&bytes).map_err(|_| "Credential file must contain valid JSON")?;
    if !v.is_object() {
        return err("Credential file must contain a JSON object");
    }
    Ok(v)
}
fn exponent(currency: &str) -> Result<u32> {
    // Explicitly support currencies whose minor-unit semantics are unambiguous here.
    match currency.to_ascii_uppercase().as_str() {
        "JPY" | "KRW" | "VND" | "CLP" => Ok(0),
        "USD" | "EUR" | "GBP" | "AUD" | "CAD" | "CHF" | "NZD" | "SEK" | "NOK" | "DKK" | "PLN"
        | "CZK" | "HKD" | "SGD" | "INR" | "BRL" | "MXN" | "ZAR" => Ok(2),
        _ => err("This currency's minor-unit rules are not supported yet"),
    }
}
fn amount(value: &Value) -> Result<i64> {
    let n = if let Some(n) = value.as_i64() {
        n
    } else {
        value.as_str().ok_or("Missing amount")?.parse()?
    };
    if n.unsigned_abs() > 1_000_000_000_000_000 {
        return err("Amount exceeds supported range");
    }
    Ok(n)
}
fn metric(label: &str, value: f64, currency: &str) -> Result<Value> {
    if !value.is_finite() || value.abs() > 1e15 {
        return err("Metric exceeds supported range");
    }
    Ok(json!({"label":label,"value":value,"currency":currency}))
}
pub fn paddle_result(revenue: &Value, mrr: &Value) -> Result<Value> {
    let currency = s(&revenue["data"], "currency_code");
    let divisor = 10f64.powi(exponent(currency)? as i32);
    if s(&mrr["data"], "currency_code") != currency {
        return err("Provider returned mismatched currencies");
    }
    let revenue_rows = revenue["data"]["timeseries"]
        .as_array()
        .ok_or("Revenue data missing")?;
    let mrr_rows = mrr["data"]["timeseries"]
        .as_array()
        .ok_or("MRR data missing")?;
    if revenue_rows.len() > 32 || mrr_rows.len() > 32 {
        return err("Provider returned an oversized series");
    }
    let mut sum = 0i64;
    let mut chart = Vec::new();
    for row in revenue_rows {
        let n = amount(&row["amount"])?;
        sum = sum.checked_add(n).ok_or("Amount overflow")?;
        chart.push(json!({"date":cut(s(row,"timestamp"),10),"value":n as f64/divisor}));
    }
    let mut metrics = vec![metric("Net revenue", sum as f64 / divisor, currency)?];
    if let Some(last) = mrr_rows.last() {
        let n = amount(&last["amount"])? as f64 / divisor;
        metrics.push(metric("MRR", n, currency)?);
        metrics.push(metric("ARR", n * 12.0, currency)?);
    }
    Ok(
        json!({"metrics":metrics,"chart":chart,"note":"UTC days. Net revenue is after tax and fees, before refunds/chargebacks. MRR is the latest reported amount; ARR is MRR × 12.","sourceUpdatedAt":revenue["data"]["updated_at"]}),
    )
}
fn stripe_pages(endpoint: &str, key: &str, query: &str, started: Instant) -> Result<Vec<Value>> {
    let mut rows = Vec::new();
    let mut after = String::new();
    for _ in 0..20 {
        if started.elapsed().as_secs() > 35 {
            return err("Report exceeded its time budget; no partial total shown");
        }
        let mut url = url::Url::parse(&format!(
            "https://api.stripe.com/v1/{endpoint}?limit=100&{query}"
        ))?;
        if !after.is_empty() {
            url.query_pairs_mut().append_pair("starting_after", &after);
        }
        let v = fetch(
            url.as_str(),
            &[
                format!("Authorization: Bearer {key}"),
                "Stripe-Version: 2025-06-30.basil".into(),
            ],
            None,
        )?;
        let batch = v["data"].as_array().ok_or("Stripe returned no rows")?;
        if batch.len() > 100 {
            return err("Stripe returned an oversized page");
        }
        rows.extend(batch.iter().cloned());
        if v["has_more"] == false {
            return Ok(rows);
        }
        let id = batch
            .last()
            .map(|r| s(r, "id"))
            .filter(|s| !s.is_empty())
            .ok_or("Stripe pagination is incomplete")?;
        if id == after {
            return err("Stripe pagination did not advance");
        }
        after = id.into();
    }
    err("Report exceeds 2,000 rows; no partial total shown")
}
pub fn stripe_result(rows: &[Value], subs: &[Value], currency: &str) -> Result<Value> {
    let divisor = 10f64.powi(exponent(currency)? as i32);
    let currency = currency.to_ascii_lowercase();
    let mut gross = 0i64;
    let mut net = 0i64;
    let mut days = std::collections::BTreeMap::<String, i64>::new();
    for r in rows {
        if s(r, "currency") != currency
            || ![
                "charge",
                "payment",
                "refund",
                "payment_refund",
                "payment_failure_refund",
                "payment_reversal",
                "refund_failure",
            ]
            .contains(&s(r, "type"))
        {
            continue;
        }
        let n = amount(&r["amount"])?;
        gross = gross.checked_add(n).ok_or("Amount overflow")?;
        net = net
            .checked_add(amount(&r["net"])?)
            .ok_or("Amount overflow")?;
        let day = chrono::DateTime::from_timestamp(
            r["created"].as_i64().ok_or("Missing transaction date")?,
            0,
        )
        .ok_or("Invalid transaction date")?
        .format("%Y-%m-%d")
        .to_string();
        let prior = days.entry(day).or_default();
        *prior = prior.checked_add(n).ok_or("Amount overflow")?;
    }
    let mut mrr = 0.0;
    let mut customers = std::collections::HashSet::new();
    let mut unsupported = false;
    for sub in subs {
        if !["active", "past_due"].contains(&s(sub, "status")) {
            continue;
        }
        if sub["discounts"].as_array().is_some_and(|v| !v.is_empty()) {
            unsupported = true;
            continue;
        }
        if sub["items"]["has_more"] == true {
            unsupported = true;
            continue;
        }
        let items = sub["items"]["data"]
            .as_array()
            .ok_or("Subscription items missing")?;
        let mut total = 0.0;
        for item in items {
            let price = &item["price"];
            if s(price, "currency") != currency || s(&price["recurring"], "usage_type") == "metered"
            {
                continue;
            }
            if s(price, "billing_scheme") != "per_unit"
                || item["discounts"].as_array().is_some_and(|v| !v.is_empty())
            {
                unsupported = true;
                continue;
            }
            let Some(unit) = price["unit_amount"].as_i64() else {
                unsupported = true;
                continue;
            };
            let count = price["recurring"]["interval_count"].as_u64().unwrap_or(0);
            let quantity = item["quantity"].as_u64().unwrap_or(1);
            if count == 0 || count > 1000 || quantity > 1_000_000 || unit < 0 {
                unsupported = true;
                continue;
            }
            let months = match s(&price["recurring"], "interval") {
                "month" => count as f64,
                "year" => count as f64 * 12.0,
                "week" => count as f64 * 12.0 / 52.0,
                "day" => count as f64 * 12.0 / 365.0,
                _ => {
                    unsupported = true;
                    continue;
                }
            };
            total += unit as f64 * quantity as f64 / months / divisor;
        }
        if total > 0.0 {
            customers.insert(s(sub, "customer").to_owned());
        }
        mrr += total;
    }
    let mut metrics = vec![
        metric("Revenue", gross as f64 / divisor, &currency)?,
        metric("Net after fees", net as f64 / divisor, &currency)?,
    ];
    if !unsupported {
        metrics.push(metric("MRR estimate", mrr, &currency)?);
        metrics.push(metric("ARR estimate", mrr * 12.0, &currency)?);
        metrics.push(metric("Paying subscribers", customers.len() as f64, "")?);
        if !customers.is_empty() {
            metrics.push(metric("ARPU", mrr / customers.len() as f64, &currency)?);
        }
    }
    let chart = days
        .into_iter()
        .map(|(date, value)| json!({"date":date,"value":value as f64/divisor}))
        .collect::<Vec<_>>();
    Ok(
        json!({"metrics":metrics,"chart":chart,"note":if unsupported{"UTC days. Subscription metrics unavailable: discounts, tiered pricing or incomplete subscription items require a more specific calculation."}else{"UTC days. Revenue includes collected tax, less refunds/reversals, before fees. Fixed active/past-due subscriptions only; trials and metered usage excluded from MRR."}}),
    )
}
pub fn shopify_result(rows: &[Value], currency: &str) -> Result<Value> {
    let mut total = 0.0;
    let mut count = 0usize;
    let mut days = std::collections::BTreeMap::<String, f64>::new();
    for row in rows {
        if row["test"] == true || !row["cancelledAt"].is_null() {
            continue;
        }
        let money = &row["currentTotalPriceSet"]["shopMoney"];
        if s(money, "currencyCode") != currency {
            return err("Order currencies do not match; no combined total shown");
        }
        let n = s(money, "amount").parse::<f64>()?;
        if !n.is_finite() || !(0.0..=1e12).contains(&n) {
            return err("Invalid order amount");
        }
        let date = chrono::DateTime::parse_from_rfc3339(s(row, "createdAt"))?
            .with_timezone(&Utc)
            .format("%Y-%m-%d")
            .to_string();
        total += n;
        count += 1;
        *days.entry(date).or_default() += n;
    }
    let mut metrics = vec![
        metric("Order value", total, currency)?,
        metric("Orders", count as f64, "")?,
    ];
    if count > 0 {
        metrics.push(metric(
            "Average order value",
            total / count as f64,
            currency,
        )?);
    }
    Ok(
        json!({"metrics":metrics,"chart":days.into_iter().map(|(date,value)|json!({"date":date,"value":value})).collect::<Vec<_>>(),"note":"UTC days. Current order totals include tax, shipping and unpaid orders; test/cancelled orders excluded. This is order value, not cash received."}),
    )
}
pub fn read_metrics(p: &Value) -> Result<Value> {
    let path = Path::new(s(p, "path"));
    if !path.is_absolute() {
        return err("Choose an absolute credential file path");
    }
    report(&load_credentials(path)?, p)
}
pub fn report(credentials: &Value, p: &Value) -> Result<Value> {
    use crate::business_period::{compare, period, zone};
    let provider = s(credentials, "provider");
    let key = if !s(p, "period").is_empty() {
        s(p, "period")
    } else {
        match p["days"].as_i64().unwrap_or(7) {
            1 => "today",
            7 => "7d",
            30 => "30d",
            _ => return err("Invalid reporting period"),
        }
    };
    let started = Instant::now();
    let now = Utc::now();
    let mut currency = s(p, "currency").to_uppercase();
    if currency.is_empty() {
        currency = "USD".into();
    }
    let mut zone_name = s(p, "timeZone").to_string();
    let mut shop_headers = Vec::new();
    let mut shop_sandbox = Value::Null;
    if provider == "shopify" {
        let shop = s(credentials, "shop");
        if !valid(shop, "^[a-z0-9][a-z0-9-]{0,62}\\.myshopify\\.com$") {
            return err("Use the store's myshopify.com domain");
        }
        let auth = fetch(
            &format!("https://{shop}/admin/oauth/access_token"),
            &[],
            Some(
                &json!({"grant_type":"client_credentials","client_id":secret(s(credentials,"clientId"))?,"client_secret":secret(s(credentials,"clientSecret"))?}),
            ),
        )?;
        shop_headers.push(format!(
            "X-Shopify-Access-Token: {}",
            secret(s(&auth, "access_token"))?
        ));
        let info = fetch(
            &format!("https://{shop}/admin/api/2026-07/graphql.json"),
            &shop_headers,
            Some(&json!({"query":"{shop{currencyCode ianaTimezone plan{partnerDevelopment}}}"})),
        )?;
        if info.get("errors").is_some() {
            return err(
                "Shopify store query denied; verify the installed app and read_orders scope",
            );
        }
        shop_sandbox = info["data"]["shop"]["plan"]["partnerDevelopment"].clone();
        currency = s(&info["data"]["shop"], "currencyCode").into();
        zone_name = s(&info["data"]["shop"], "ianaTimezone").into();
        if zone_name.is_empty() {
            return err("Shopify did not report its time zone");
        }
    } else if provider == "paddle" {
        zone_name = "UTC".into();
    }
    let period = period(key, zone(&zone_name)?, now)?;
    let mut series = json!({});
    let mut comparison_unavailable = false;
    let (mut current, previous) = match provider {
        "stripe" => {
            let key = secret(s(credentials, "apiKey"))?;
            if !key.starts_with("rk_live_") && !key.starts_with("rk_test_") {
                return err("Use a Stripe restricted read-only key");
            }
            exponent(&currency)?;
            let rows = stripe_pages(
                "balance_transactions",
                key,
                &format!(
                    "created[gte]={}&created[lt]={}",
                    period.previous_start.timestamp(),
                    period.end.timestamp()
                ),
                started,
            )?;
            let subs = stripe_pages("subscriptions", key, "status=all", started)?;
            let select = |start: i64, end: i64| {
                rows.iter()
                    .filter(|r| r["created"].as_i64().is_some_and(|t| t >= start && t < end))
                    .cloned()
                    .collect::<Vec<_>>()
            };
            let current_rows = select(period.start.timestamp(), period.end.timestamp());
            let prior_rows = select(
                period.previous_start.timestamp(),
                period.previous_end.timestamp(),
            );
            let mut previous = stripe_result(&prior_rows, &[], &currency)?;
            previous["metrics"].as_array_mut().unwrap().truncate(2); // No invented historical subscription snapshot.
            series_for_rows(&current_rows, &period, &currency, true, &mut series)?;
            (stripe_result(&current_rows, &subs, &currency)?, previous)
        }
        "paddle" => {
            let key = secret(s(credentials, "apiKey"))?;
            let host = if key.starts_with("pdl_sdbx_apikey_") {
                "sandbox-api.paddle.com"
            } else if key.starts_with("pdl_live_apikey_") {
                "api.paddle.com"
            } else {
                return err("Use a Paddle Billing API key");
            };
            let headers = [format!("Authorization: Bearer {key}")];
            let end = period.last + Duration::days(1);
            let revenue = fetch(
                &format!(
                    "https://{host}/metrics/revenue?from={}&to={end}",
                    period.previous_first
                ),
                &headers,
                None,
            )?;
            let mrr = fetch(
                &format!(
                    "https://{host}/metrics/monthly-recurring-revenue?from={}&to={end}",
                    period.previous_first
                ),
                &headers,
                None,
            )?;
            let slice = |v: &Value,
                         first: chrono::NaiveDate,
                         last: chrono::NaiveDate|
             -> Result<Value> {
                let rows = v["data"]["timeseries"]
                    .as_array()
                    .ok_or("Paddle series unavailable")?;
                if rows.len() > 64 {
                    return err("Provider returned an oversized series");
                }
                let rows = rows
                    .iter()
                    .filter(|r| {
                        let day = cut(s(r, "timestamp"), 10);
                        day >= first.to_string() && day <= last.to_string()
                    })
                    .cloned()
                    .collect::<Vec<_>>();
                Ok(
                    json!({"data":{"timeseries":rows,"currency_code":v["data"]["currency_code"],"updated_at":v["data"]["updated_at"]}}),
                )
            };
            let a = slice(&revenue, period.first, period.last)?;
            let b = slice(&mrr, period.first, period.last)?;
            currency = s(&a["data"], "currency_code").into();
            let current = paddle_result(&a, &b)?;
            series["Net revenue"] = current["chart"].clone();
            let divisor = 10f64.powi(exponent(s(&b["data"], "currency_code"))? as i32);
            let points=b["data"]["timeseries"].as_array().unwrap().iter().map(|r|Ok(json!({"date":cut(s(r,"timestamp"),10),"value":amount(&r["amount"])? as f64/divisor}))).collect::<Result<Vec<_>>>()?;
            series["MRR"] = json!(points);
            series["ARR"] = json!(points
                .iter()
                .map(|p| json!({"date":p["date"],"value":p["value"].as_f64().unwrap()*12.0}))
                .collect::<Vec<_>>());
            (
                current,
                paddle_result(
                    &slice(&revenue, period.previous_first, period.previous_last)?,
                    &slice(&mrr, period.previous_first, period.previous_last)?,
                )?,
            )
        }
        "shopify" => {
            let shop = s(credentials, "shop");
            comparison_unavailable = period.previous_start < now - Duration::days(60);
            let query_start = if comparison_unavailable {
                period.start
            } else {
                period.previous_start
            };
            let query="query($after:String,$query:String!){orders(first:100,after:$after,query:$query,sortKey:CREATED_AT){nodes{createdAt cancelledAt test currentTotalPriceSet{shopMoney{amount currencyCode}}}pageInfo{hasNextPage endCursor}}}";
            let mut after = Value::Null;
            let mut rows = Vec::new();
            let mut complete = false;
            for _ in 0..100 {
                if started.elapsed().as_secs() > 35 {
                    return err("Report exceeded its time budget; no partial total shown");
                }
                let result = fetch(
                    &format!("https://{shop}/admin/api/2026-07/graphql.json"),
                    &shop_headers,
                    Some(
                        &json!({"query":query,"variables":{"after":after,"query":format!("created_at:>='{}' created_at:<'{}'",query_start.to_rfc3339(),period.end.to_rfc3339())}}),
                    ),
                )?;
                if result.get("errors").is_some() {
                    return err(
                        "Shopify query failed; check read_orders permissions and API compatibility",
                    );
                }
                let orders = &result["data"]["orders"];
                let batch = orders["nodes"].as_array().ok_or("Orders unavailable")?;
                if batch.len() > 100 {
                    return err("Oversized order page");
                }
                rows.extend(batch.iter().cloned());
                if orders["pageInfo"]["hasNextPage"] == false {
                    complete = true;
                    break;
                }
                let next = &orders["pageInfo"]["endCursor"];
                if !next.is_string() || next == &after {
                    return err("Shopify pagination did not advance");
                }
                after = next.clone();
            }
            if !complete {
                return err("Report exceeds 10,000 orders including the comparison period; no partial total shown");
            }
            let select =
                |start: chrono::DateTime<Utc>, end: chrono::DateTime<Utc>| -> Result<Vec<Value>> {
                    let mut result = Vec::new();
                    for row in &rows {
                        let at = chrono::DateTime::parse_from_rfc3339(s(row, "createdAt"))?
                            .with_timezone(&Utc);
                        if at >= start && at < end {
                            result.push(row.clone());
                        }
                    }
                    Ok(result)
                };
            let current = select(period.start, period.end)?;
            let previous = select(period.previous_start, period.previous_end)?;
            series_for_rows(&current, &period, &currency, false, &mut series)?;
            (
                shopify_result(&current, &currency)?,
                shopify_result(&previous, &currency)?,
            )
        }
        _ => return err("Credential provider must be stripe, paddle or shopify"),
    };
    let previous = if comparison_unavailable {
        json!({"metrics":[]})
    } else {
        previous
    };
    compare(&mut current, &previous);
    for points in series
        .as_object_mut()
        .ok_or("Invalid chart data")?
        .values_mut()
    {
        let observed = points.as_array().ok_or("Invalid chart series")?.clone();
        let mut filled = Vec::new();
        let mut day = period.first;
        while day <= period.last {
            let value = observed
                .iter()
                .find(|p| s(p, "date") == day.to_string())
                .map(|p| p["value"].clone())
                .unwrap_or(Value::Null);
            filled.push(json!({"date":day.to_string(),"value":value}));
            day += Duration::days(1);
        }
        *points = json!(filled);
    }
    let first_label = current["metrics"]
        .as_array()
        .and_then(|m| m.first())
        .map(|m| s(m, "label"))
        .unwrap_or("");
    current["chart"] = series[first_label].clone();
    current["series"] = series;
    current["period"] = period.metadata();
    if provider == "paddle" {
        current["period"]["comparisonLabel"] =
            "Previous equal-length UTC day range; current day may be incomplete".into();
    }
    current["note"] = s(&current, "note")
        .replace(
            "UTC days.",
            "See reporting time zone and comparison dates below.",
        )
        .into();
    current["sandbox"] = match provider {
        "stripe" => json!(s(credentials, "apiKey").starts_with("rk_test_")),
        "paddle" => json!(s(credentials, "apiKey").starts_with("pdl_sdbx_")),
        _ => shop_sandbox,
    };
    if comparison_unavailable {
        current["period"]["comparisonLabel"]="Comparison unavailable: this period extends beyond Shopify’s standard 60-day order access".into();
    }
    current["provider"] = provider.into();
    current["updatedAt"] = now.timestamp().into();
    current["currency"] = currency.into();
    Ok(current)
}
fn series_for_rows(
    rows: &[Value],
    period: &crate::business_period::Period,
    currency: &str,
    stripe: bool,
    series: &mut Value,
) -> Result<()> {
    let mut grouped = std::collections::BTreeMap::<String, Vec<Value>>::new();
    for row in rows {
        let at = if stripe {
            row["created"].as_i64().ok_or("Missing date")?
        } else {
            chrono::DateTime::parse_from_rfc3339(s(row, "createdAt"))?.timestamp()
        };
        grouped
            .entry(period.day(at)?)
            .or_default()
            .push(row.clone());
    }
    let labels = if stripe {
        vec!["Revenue", "Net after fees"]
    } else {
        vec!["Order value", "Orders", "Average order value"]
    };
    for label in &labels {
        series[*label] = json!([]);
    }
    let mut date = period.first;
    while date <= period.last {
        let rows = grouped.remove(&date.to_string()).unwrap_or_default();
        let result = if stripe {
            stripe_result(&rows, &[], currency)?
        } else {
            shopify_result(&rows, currency)?
        };
        for label in &labels {
            let value = result["metrics"]
                .as_array()
                .unwrap()
                .iter()
                .find(|m| s(m, "label") == *label)
                .map(|m| m["value"].clone())
                .unwrap_or(Value::Null);
            series[*label]
                .as_array_mut()
                .unwrap()
                .push(json!({"date":date.to_string(),"value":value}));
        }
        date += Duration::days(1);
    }
    Ok(())
}
