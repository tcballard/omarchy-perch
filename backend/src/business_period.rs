//! Calendar periods with IANA-zone boundaries (never a fixed UTC offset).
use crate::core::*;
use chrono::{DateTime, Datelike, Duration, NaiveDate, TimeZone, Utc};
use chrono_tz::Tz;
use serde_json::{json, Value};
#[derive(Clone)]
pub struct Period {
    pub zone: Tz,
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
    pub previous_start: DateTime<Utc>,
    pub previous_end: DateTime<Utc>,
    pub first: NaiveDate,
    pub last: NaiveDate,
    pub previous_first: NaiveDate,
    pub previous_last: NaiveDate,
}
pub fn zone(name: &str) -> Result<Tz> {
    let name = if name.is_empty() || name == "local" {
        iana_time_zone::get_timezone()
            .map_err(|_| "Cannot determine local time zone; choose an IANA zone")?
    } else {
        name.into()
    };
    name.parse()
        .map_err(|_| "Choose a valid IANA time zone, such as Europe/London".into())
}
fn midnight(zone: Tz, day: NaiveDate) -> Result<DateTime<Utc>> {
    let midnight = day.and_hms_opt(0, 0, 0).ok_or("Invalid date")?;
    // A few zones advance at midnight; use their first valid minute that day.
    for minute in 0..180 {
        if let Some(t) = zone
            .from_local_datetime(&(midnight + Duration::minutes(minute)))
            .earliest()
        {
            return Ok(t.with_timezone(&Utc));
        }
    }
    err("Reporting date has no supported local midnight")
}
pub fn period(key: &str, zone: Tz, now: DateTime<Utc>) -> Result<Period> {
    let local = now.with_timezone(&zone);
    let last = local.date_naive();
    let first = match key {
        "today" => last,
        "7d" => last - Duration::days(6),
        "30d" => last - Duration::days(29),
        "mtd" => last.with_day(1).unwrap(),
        _ => return err("Choose Today, 7 days, Month to date or 30 days"),
    };
    let days = (last - first).num_days() + 1;
    let previous_first = first - Duration::days(days);
    let previous_last = last - Duration::days(days);
    let previous_end = zone
        .from_local_datetime(&previous_last.and_time(local.time()))
        .earliest()
        .ok_or("Previous period ends in a daylight-saving gap; refresh later")?
        .with_timezone(&Utc);
    Ok(Period {
        zone,
        start: midnight(zone, first)?,
        end: now,
        previous_start: midnight(zone, previous_first)?,
        previous_end,
        first,
        last,
        previous_first,
        previous_last,
    })
}
impl Period {
    pub fn metadata(&self) -> Value {
        json!({"timeZone":self.zone.name(),"start":self.start.to_rfc3339(),"end":self.end.to_rfc3339(),"previousStart":self.previous_start.to_rfc3339(),"previousEnd":self.previous_end.to_rfc3339(),"first":self.first.to_string(),"last":self.last.to_string(),"previousFirst":self.previous_first.to_string(),"previousLast":self.previous_last.to_string(),"comparisonLabel":"Previous equal-length calendar period, through the same local time"})
    }
    pub fn day(&self, seconds: i64) -> Result<String> {
        Ok(DateTime::from_timestamp(seconds, 0)
            .ok_or("Invalid date")?
            .with_timezone(&self.zone)
            .format("%Y-%m-%d")
            .to_string())
    }
}
pub fn compare(current: &mut Value, previous: &Value) {
    if let Some(rows) = current["metrics"].as_array_mut() {
        for row in rows {
            let prior = previous["metrics"]
                .as_array()
                .and_then(|rows| {
                    rows.iter()
                        .find(|p| p["label"] == row["label"] && p["currency"] == row["currency"])
                })
                .and_then(|p| p["value"].as_f64());
            row["previous"] = prior.map_or(Value::Null, Value::from);
            row["changePercent"] = match (prior, row["value"].as_f64()) {
                (Some(p), Some(c)) if p != 0.0 => Value::from((c - p) / p.abs() * 100.0),
                _ => Value::Null,
            };
        }
    }
}
