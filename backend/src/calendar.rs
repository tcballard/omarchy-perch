use crate::{
    core::*,
    desktop::{local, web_url},
};
use chrono::{Datelike, Duration, NaiveDate, NaiveDateTime, Timelike};
use serde_json::{json, Value};
use std::{
    collections::{HashMap, HashSet},
    path::Path,
};
type Property = (String, HashMap<String, String>);
#[derive(Clone, Default)]
struct Props {
    values: HashMap<String, Vec<Property>>,
    children: HashMap<String, Vec<Props>>,
}
impl Props {
    fn one(&self, k: &str) -> &str {
        self.values
            .get(k)
            .and_then(|v| v.first())
            .map(|v| v.0.as_str())
            .unwrap_or("")
    }
    fn date(&self, k: &str, zones: &HashMap<String, Zone>) -> Result<Stamp> {
        let (v, p) = self
            .values
            .get(k)
            .and_then(|v| v.first())
            .ok_or("Missing calendar date")?;
        date(v, p, zones)
    }
}
fn components(text: &str) -> Vec<(String, Props)> {
    let mut stack: Vec<(String, Props)> = Vec::new();
    let mut records = Vec::new();
    for line in text.lines() {
        if let Some(kind) = line.strip_prefix("BEGIN:") {
            stack.push((kind.to_uppercase(), Props::default()));
        } else if let Some(kind) = line.strip_prefix("END:") {
            if stack.last().is_some_and(|v| v.0 == kind.to_uppercase()) {
                let (kind, props) = stack.pop().unwrap();
                if ["VEVENT", "VTIMEZONE"].contains(&kind.as_str()) {
                    records.push((kind, props));
                } else if ["STANDARD", "DAYLIGHT"].contains(&kind.as_str()) {
                    if let Some(parent) = stack.last_mut() {
                        parent.1.children.entry(kind).or_default().push(props);
                    }
                }
            }
        } else if let Some(parent) = stack.last_mut() {
            if ["VEVENT", "VTIMEZONE", "STANDARD", "DAYLIGHT"].contains(&parent.0.as_str()) {
                if let Some((head, val)) = line.split_once(':') {
                    let mut parts = head.split(';');
                    let key = parts.next().unwrap().to_uppercase();
                    let params = parts
                        .filter_map(|x| x.split_once('='))
                        .map(|(k, v)| (k.to_owned(), v.trim_matches('"').to_owned()))
                        .collect();
                    parent
                        .1
                        .values
                        .entry(key)
                        .or_default()
                        .push((val.to_owned(), params));
                }
            }
        }
    }
    records
}
#[derive(Clone)]
struct Rule {
    offset: i32,
    month: Option<u32>,
    nth: i32,
    weekday: u32,
    time: chrono::NaiveTime,
}
#[derive(Clone)]
enum Zone {
    System(String),
    Rules(Rule, Option<Rule>),
    Utc,
}
#[derive(Clone)]
struct Stamp {
    wall: NaiveDateTime,
    zone: Zone,
}
impl Stamp {
    fn epoch(&self) -> Result<i64> {
        match &self.zone {
            Zone::Utc => Ok(self.wall.and_utc().timestamp()),
            Zone::Rules(standard, daylight) => {
                let mut offset = standard.offset;
                if let Some(d) = daylight {
                    if d.month.is_some() {
                        let on = transition(d, self.wall.year())?;
                        let off = transition(standard, self.wall.year())?;
                        if if on < off {
                            self.wall >= on && self.wall < off
                        } else {
                            self.wall >= on || self.wall < off
                        } {
                            offset = d.offset;
                        }
                    }
                }
                Ok(self.wall.and_utc().timestamp() - offset as i64)
            }
            Zone::System(name) => {
                let old = std::env::var_os("TZ");
                if !name.is_empty() {
                    if name.contains("..")
                        || name.starts_with('/')
                        || !Path::new("/usr/share/zoneinfo").join(name).is_file()
                    {
                        return err(&format!("Unknown time zone {}", cut(name, 60)));
                    }
                    std::env::set_var("TZ", name);
                }
                unsafe extern "C" {
                    fn tzset();
                }
                unsafe {
                    tzset();
                }
                let mut t: libc::tm = unsafe { std::mem::zeroed() };
                t.tm_year = self.wall.year() - 1900;
                t.tm_mon = self.wall.month() as i32 - 1;
                t.tm_mday = self.wall.day() as i32;
                t.tm_hour = self.wall.hour() as i32;
                t.tm_min = self.wall.minute() as i32;
                t.tm_sec = self.wall.second() as i32;
                t.tm_isdst = -1;
                let epoch = unsafe { libc::mktime(&mut t) };
                if !name.is_empty() {
                    if let Some(old) = old {
                        std::env::set_var("TZ", old)
                    } else {
                        std::env::remove_var("TZ")
                    }
                    unsafe {
                        tzset();
                    }
                }
                Ok(epoch)
            }
        }
    }
}
fn transition(r: &Rule, year: i32) -> Result<NaiveDateTime> {
    let month = r.month.ok_or("Invalid timezone rule")?;
    let start = NaiveDate::from_ymd_opt(year, month, 1).ok_or("Invalid timezone month")?;
    let day = if r.nth > 0 {
        start
            + Duration::days(
                ((r.weekday + 7 - start.weekday().num_days_from_monday()) % 7
                    + 7 * (r.nth as u32 - 1)) as i64,
            )
    } else {
        let last = if month == 12 {
            NaiveDate::from_ymd_opt(year + 1, 1, 1)
        } else {
            NaiveDate::from_ymd_opt(year, month + 1, 1)
        }
        .ok_or("Invalid timezone year")?
            - Duration::days(1);
        last - Duration::days(
            ((last.weekday().num_days_from_monday() + 7 - r.weekday) % 7 + 7 * (-r.nth as u32 - 1))
                as i64,
        )
    };
    Ok(day.and_time(r.time))
}
const DAYS: [&str; 7] = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"];
fn rule(p: &Props) -> Result<Rule> {
    let text = p.one("TZOFFSETTO");
    let digits = text.trim_start_matches(['+', '-']);
    if !valid(digits, r"^\d{4}(\d{2})?$") {
        return err("Invalid UTC offset");
    };
    let offset = (digits[..2].parse::<i32>()? * 3600
        + digits[2..4].parse::<i32>()? * 60
        + digits.get(4..6).unwrap_or("0").parse::<i32>()?)
        * if text.starts_with('-') { -1 } else { 1 };
    let map = rrule(p.one("RRULE"));
    let mut r = Rule {
        offset,
        month: None,
        nth: 0,
        weekday: 0,
        time: chrono::NaiveTime::from_hms_opt(2, 0, 0).unwrap(),
    };
    let re = regex::Regex::new(r"^(-?[1-4])(MO|TU|WE|TH|FR|SA|SU)$")?;
    if map.get("FREQ").is_some_and(|v| v == "YEARLY") {
        if let Some(m) = map.get("BYDAY").and_then(|s| re.captures(s)) {
            r.month = Some(map.get("BYMONTH").ok_or("Invalid timezone rule")?.parse()?);
            r.nth = m[1].parse()?;
            r.weekday = DAYS.iter().position(|v| *v == &m[2]).unwrap() as u32;
            let stamp = p.one("DTSTART");
            r.time = chrono::NaiveTime::parse_from_str(
                stamp.get(stamp.len().saturating_sub(6)..).unwrap_or(""),
                "%H%M%S",
            )?;
        }
    }
    Ok(r)
}
fn rrule(s: &str) -> HashMap<String, String> {
    s.split(';')
        .filter_map(|v| v.split_once('='))
        .map(|(k, v)| (k.into(), v.into()))
        .collect()
}
fn date(
    value: &str,
    params: &HashMap<String, String>,
    zones: &HashMap<String, Zone>,
) -> Result<Stamp> {
    let wall = if value.len() == 8 {
        NaiveDate::parse_from_str(value, "%Y%m%d")?
            .and_hms_opt(0, 0, 0)
            .unwrap()
    } else {
        NaiveDateTime::parse_from_str(value.trim_end_matches('Z'), "%Y%m%dT%H%M%S")?
    };
    let name = params.get("TZID").cloned().unwrap_or_default();
    let zone = if value.ends_with('Z') {
        Zone::Utc
    } else if value.len() == 8 {
        Zone::System(String::new())
    } else {
        zones.get(&name).cloned().unwrap_or(Zone::System(name))
    };
    let result = Stamp { wall, zone };
    result.epoch()?;
    Ok(result)
}
fn duration(s: &str) -> Result<i64> {
    let re = regex::Regex::new(
        r"^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$",
    )?;
    let m = re.captures(s).ok_or("Invalid duration")?;
    let mut total = 0i64;
    for (i, mult) in [(2, 604800), (3, 86400), (4, 3600), (5, 60), (6, 1)] {
        total = total
            .checked_add(
                m.get(i)
                    .map(|v| v.as_str().parse::<i64>())
                    .transpose()?
                    .unwrap_or(0)
                    .checked_mul(mult)
                    .ok_or("Invalid duration")?,
            )
            .ok_or("Invalid duration")?;
    }
    Ok(if m.get(1).is_some_and(|s| s.as_str() == "-") {
        -total
    } else {
        total
    })
}
fn unescape(s: &str) -> String {
    s.replace("\\n", "\n")
        .replace("\\N", "\n")
        .replace("\\,", ",")
        .replace("\\;", ";")
        .replace("\\\\", "\\")
}
pub fn parse(data: &[u8], now: i64) -> Result<(Vec<Value>, usize)> {
    let text = std::str::from_utf8(data)?.trim_start_matches('\u{feff}');
    let text = regex::Regex::new(r"\r?\n[ \t]")?.replace_all(text, "");
    if !text.contains("BEGIN:VCALENDAR") || !text.contains("END:VCALENDAR") {
        return err("Not an iCalendar document");
    };
    let mut zones = HashMap::new();
    let mut records = Vec::new();
    for (kind, props) in components(&text) {
        if kind == "VTIMEZONE" {
            let parsed = (|| {
                let standard = props
                    .children
                    .get("STANDARD")
                    .or_else(|| props.children.get("DAYLIGHT"))
                    .and_then(|v| v.first())
                    .ok_or("Invalid timezone")?;
                Ok::<_, Box<dyn std::error::Error>>(Zone::Rules(
                    rule(standard)?,
                    props
                        .children
                        .get("DAYLIGHT")
                        .and_then(|v| v.first())
                        .map(rule)
                        .transpose()?,
                ))
            })();
            if let Ok(zone) = parsed {
                zones.insert(props.one("TZID").to_string(), zone);
            }
        } else {
            records.push(props);
            if records.len() > 2000 {
                return err("Calendar exceeds 2000 events");
            }
        }
    }
    let horizon = now + 30 * 86400;
    let mut overrides: HashMap<String, HashSet<i64>> = HashMap::new();
    for r in &records {
        if let Ok(d) = r.date("RECURRENCE-ID", &zones) {
            if !r.one("UID").is_empty() {
                overrides
                    .entry(r.one("UID").into())
                    .or_default()
                    .insert(d.epoch()?);
            }
        }
    }
    let mut events = Vec::new();
    let mut unsupported = 0;
    let link_pattern = regex::Regex::new(r#"https?://[^\s<>"\\]+"#)?;
    for r in &records {
        if cancelled() {
            return err("Calendar read cancelled");
        }
        let result = (|| -> Result<()> {
            if r.one("STATUS") == "CANCELLED" {
                return Ok(());
            };
            let start = r.date("DTSTART", &zones)?;
            let epoch = start.epoch()?;
            let allday = r.one("DTSTART").len() == 8;
            let end = if r.values.contains_key("DTEND") {
                r.date("DTEND", &zones)?.wall
            } else if r.values.contains_key("DURATION") {
                start
                    .wall
                    .checked_add_signed(Duration::seconds(duration(r.one("DURATION"))?))
                    .ok_or("Invalid duration")?
            } else {
                start.wall + Duration::seconds(if allday { 86400 } else { 3600 })
            };
            let length = if end > start.wall {
                end - start.wall
            } else {
                Duration::minutes(30)
            };
            let mut starts = vec![start.clone()];
            if r.values.contains_key("RRULE") && !r.values.contains_key("RECURRENCE-ID") {
                let rule = rrule(r.one("RRULE"));
                let freq = rule.get("FREQ").map(String::as_str).unwrap_or("");
                if !["DAILY", "WEEKLY"].contains(&freq)
                    || rule.keys().any(|k| {
                        !["FREQ", "INTERVAL", "COUNT", "UNTIL", "BYDAY", "WKST"]
                            .contains(&k.as_str())
                    })
                {
                    return err("Unsupported recurrence");
                };
                let interval = rule
                    .get("INTERVAL")
                    .map(|s| s.parse::<i64>())
                    .transpose()?
                    .unwrap_or(1);
                let count = rule
                    .get("COUNT")
                    .map(|s| s.parse::<i64>())
                    .transpose()?
                    .unwrap_or(10000);
                if interval < 1 || count < 1 {
                    return err("Invalid recurrence");
                };
                let until = rule
                    .get("UNTIL")
                    .map(|s| date(s, &HashMap::new(), &zones).and_then(|s| s.epoch()))
                    .transpose()?
                    .unwrap_or(horizon);
                let default = DAYS[start.wall.weekday().num_days_from_monday() as usize];
                let days: Vec<_> = rule
                    .get("BYDAY")
                    .map(String::as_str)
                    .unwrap_or(default)
                    .split(',')
                    .collect();
                if days.iter().any(|d| !DAYS.contains(d)) {
                    return err("Unsupported recurrence");
                };
                let weekstart = DAYS
                    .iter()
                    .position(|d| *d == rule.get("WKST").map(String::as_str).unwrap_or("MO"))
                    .ok_or("Unsupported recurrence")? as i64;
                let behind = ((now - length.num_seconds() - epoch) / 86400).max(0);
                let first = if rule.contains_key("COUNT") {
                    0
                } else {
                    let step = if freq == "DAILY" {
                        interval
                    } else {
                        7 * interval
                    };
                    behind / step * step
                };
                let mut occurrences = 0;
                starts.clear();
                let mut finished = false;
                for i in first..first + 20000 {
                    if cancelled() {
                        return err("Calendar read cancelled");
                    }
                    let wall = start
                        .wall
                        .checked_add_signed(Duration::days(i))
                        .ok_or("Recurrence exceeds date range")?;
                    let stamp = Stamp {
                        wall,
                        zone: start.zone.clone(),
                    };
                    let time = stamp.epoch()?;
                    if time > until.min(horizon) || occurrences >= count {
                        finished = true;
                        break;
                    }
                    let week = |d: NaiveDateTime| {
                        d.date()
                            - Duration::days(
                                (d.weekday().num_days_from_monday() as i64 - weekstart + 7) % 7,
                            )
                    };
                    let weeks = (week(wall) - week(start.wall)).num_days() / 7;
                    let matches = if freq == "DAILY" {
                        i % interval == 0
                            && (!rule.contains_key("BYDAY")
                                || days.contains(
                                    &DAYS[wall.weekday().num_days_from_monday() as usize],
                                ))
                    } else {
                        weeks % interval == 0
                            && days.contains(&DAYS[wall.weekday().num_days_from_monday() as usize])
                    };
                    if matches {
                        occurrences += 1;
                        if time + length.num_seconds() > now {
                            starts.push(stamp)
                        }
                    }
                }
                if !finished {
                    unsupported += 1;
                }
            }
            let mut excluded = if r.values.contains_key("RECURRENCE-ID") {
                HashSet::new()
            } else {
                overrides.get(r.one("UID")).cloned().unwrap_or_default()
            };
            if let Some(exdates) = r.values.get("EXDATE") {
                for (v, p) in exdates {
                    for x in v.split(',') {
                        excluded.insert(date(x, p, &zones)?.epoch()?);
                    }
                }
            }
            let mut link = r.one("URL").to_string();
            if link.is_empty() {
                let text = unescape(&format!("{} {}", r.one("DESCRIPTION"), r.one("LOCATION")));
                if let Some(m) = link_pattern.find(&text) {
                    link = m
                        .as_str()
                        .trim_end_matches(['.', ',', ';', ':', ')', ']', '}', '\''])
                        .into();
                }
            }
            if web_url(&link).is_err() {
                link.clear()
            }
            for stamp in starts {
                let time = stamp.epoch()?;
                let eventend = Stamp {
                    wall: stamp.wall + length,
                    zone: stamp.zone.clone(),
                }
                .epoch()?;
                if excluded.contains(&time) || eventend <= now || time > horizon {
                    continue;
                }
                events.push(json!({"title":cut(&unescape(if r.one("SUMMARY").is_empty(){"Untitled event"}else{r.one("SUMMARY")}),160),"allDay":allday,"start":time*1000,"end":eventend*1000,"location":cut(&unescape(r.one("LOCATION")),200),"url":link}));
            }
            Ok(())
        })();
        if result.is_err() {
            unsupported += 1;
        }
    }
    Ok((events, unsupported))
}
pub fn handle(op: &str, p: &Value) -> Result<Value> {
    let store = Store::new("calendar")?;
    let data = store.load(json!([]))?;
    let mut paths = data
        .as_array()
        .filter(|v| v.len() <= 8 && v.iter().all(Value::is_string))
        .ok_or("Calendar state is invalid")?
        .clone();
    if op == "calendar-add" {
        let path = local(s(p, "path"))?;
        if !path
            .extension()
            .is_some_and(|s| s.to_string_lossy().eq_ignore_ascii_case("ics"))
        {
            return err("Choose an .ics calendar file");
        };
        parse(&read(&path, 1048576, false)?, now() as i64)?;
        let value = json!(path);
        if !paths.contains(&value) {
            paths.push(value)
        }
        if paths.len() > 8 {
            return err("At most eight calendar sources are supported");
        };
        store.save(&json!(paths))?;
    } else if op == "calendar-remove" {
        paths.retain(|v| v != &p["path"]);
        store.save(&json!(paths))?;
    } else if !["calendar-list", "calendar-join"].contains(&op) {
        return err("Unsupported calendar operation");
    };
    let mut events = Vec::new();
    let mut warnings = Vec::new();
    for path in &paths {
        let path = Path::new(path.as_str().unwrap());
        match read(path, 1048576, false).and_then(|data| parse(&data, now() as i64)) {
            Ok((found, skipped)) => {
                events.extend(found);
                if skipped > 0 {
                    warnings.push(format!(
                        "{}: {skipped} unsupported or invalid events",
                        path.file_name().unwrap_or_default().to_string_lossy()
                    ));
                }
            }
            Err(_) => warnings.push(format!(
                "{}: unavailable or invalid",
                path.file_name().unwrap_or_default().to_string_lossy()
            )),
        }
    }
    events.sort_by_key(|e| e["start"].as_i64().unwrap_or(0));
    events.truncate(60);
    if op == "calendar-join" {
        let url = web_url(s(p, "url"))?;
        if !events.iter().any(|e| e["url"] == url) {
            return err("Meeting link is no longer in the current agenda");
        };
        launch(&["xdg-open", url])?;
    }
    let message = if !warnings.is_empty() {
        cut(&warnings.join("; "), 500)
    } else if events.is_empty() {
        "No events in the next 30 days".into()
    } else {
        String::new()
    };
    Ok(json!({"events":events,"sources":paths,"message":message}))
}
