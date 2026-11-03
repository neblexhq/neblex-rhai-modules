// Date cleanup functions for Neblex Code steps.
// Import the module as "dates" in a Code step, then call the functions directly,
// for example item.order_date = to_iso_date(item.order_date, "mdy");
// Every function is pure and works on text and whole numbers only; results are ISO dates (YYYY-MM-DD).

// True for leap years in the Gregorian calendar.
fn is_leap_year(y) {
    (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

// Number of days in a month (1-12) of a given year. 0 for an invalid month.
fn days_in_month(y, m) {
    switch m {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 => if is_leap_year(y) { 29 } else { 28 },
        _ => 0
    }
}

// Formats year, month and day as YYYY-MM-DD, or "" when they aren't a real date.
fn iso_from_parts(y, m, d) {
    if y < 1 || y > 9999 || m < 1 || m > 12 || d < 1 || d > days_in_month(y, m) { return ""; }
    let ys = y.to_string();
    while ys.len() < 4 { ys = "0" + ys; }
    let ms = if m < 10 { "0" + m } else { m.to_string() };
    let ds = if d < 10 { "0" + d } else { d.to_string() };
    ys + "-" + ms + "-" + ds
}

// True when the value is exactly YYYY-MM-DD and a real calendar date (2026-02-30 is false).
fn is_valid_iso_date(v) {
    if type_of(v) != "string" || v.len() != 10 { return false; }
    if v.sub_string(4, 1) != "-" || v.sub_string(7, 1) != "-" { return false; }
    let ys = v.sub_string(0, 4);
    let ms = v.sub_string(5, 2);
    let ds = v.sub_string(8, 2);
    for part in [ys, ms, ds] {
        for c in part {
            if c < '0' || c > '9' { return false; }
        }
    }
    iso_from_parts(parse_int(ys), parse_int(ms), parse_int(ds)) == v
}

// Month number (1-12) from an English month name or abbreviation, 0 if it isn't one.
fn month_from_name(w) {
    let k = w.to_lower();
    if k.len() < 3 { return 0; }
    let names = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
    let i = names.index_of(k.sub_string(0, 3));
    if i < 0 { return 0; }
    let full = ["january", "february", "march", "april", "may", "june", "july", "august",
                "september", "october", "november", "december"];
    // Accept "Sept" and any prefix of the full name, but not words like "marching".
    if k == "sept" || full[i].starts_with(k) { return i + 1; }
    0
}

// Two-digit years: 00-69 become 2000-2069, 70-99 become 1970-1999.
fn full_year(y, digits) {
    if digits > 2 { return y; }
    if y < 70 { 2000 + y } else { 1900 + y }
}

// Converts a date written in common formats to YYYY-MM-DD. Returns "" when it can't be read
// or isn't a real date. `order` says how to read all-number dates such as 04/03/2026:
// "mdy" (US, April 3) or "dmy" (most other countries, 4 March). Dates that start with a
// four-digit year are always read as year, month, day. A time after the date is ignored.
// Accepts, for example: 2026-04-03, 2026/4/3, 20260403, 04/03/2026, 4/3/26, 03.04.2026,
// 3 Apr 2026, April 3rd, 2026, Fri, 3-Apr-26 and 2026-04-03T10:20:00Z.
fn to_iso_date(v, order) {
    let t = type_of(v);
    if t == "i64" {
        v = v.to_string();
    } else if t != "string" {
        return "";
    }
    let s = v;
    s.trim();
    // Drop a time: cut at the space or "T" before the first colon.
    let colon = s.index_of(':');
    if colon > 0 {
        let cut = -1;
        let i = 0;
        for c in s {
            if i >= colon { break; }
            if c == ' ' || c == 'T' || c == 't' { cut = i; }
            i += 1;
        }
        if cut > 0 { s = s.sub_string(0, cut); }
    }
    // Split into runs of digits and runs of letters.
    let nums = [];
    let num_lens = [];
    let month = 0;
    let token = "";
    let kind = "";
    for c in s + " " {
        let k = if c >= '0' && c <= '9' { "d" } else if c.to_upper() != c.to_lower() { "a" } else { "" };
        if k != kind && token != "" {
            if kind == "d" {
                nums.push(parse_int(token));
                num_lens.push(token.len());
            } else {
                let m = month_from_name(token);
                if m > 0 {
                    if month > 0 { return ""; }
                    month = m;
                }
                // Other words (weekdays, "st", "nd", "rd", "th", "of") are ignored.
            }
            token = "";
        }
        kind = k;
        if k != "" { token += c; }
    }
    // A single 8-digit number: YYYYMMDD.
    if month == 0 && nums.len() == 1 && num_lens[0] == 8 {
        let n = nums[0];
        return iso_from_parts(n / 10000, (n / 100) % 100, n % 100);
    }
    if month > 0 {
        if nums.len() != 2 { return ""; }
        // The four-digit number is the year. Otherwise the first number is the day and the
        // second the year, both in "3 Apr 26" and "Apr 3, 26".
        if num_lens[0] == 4 { return iso_from_parts(nums[0], month, nums[1]); }
        return iso_from_parts(full_year(nums[1], num_lens[1]), month, nums[0]);
    }
    if nums.len() != 3 { return ""; }
    if num_lens[0] == 4 { return iso_from_parts(nums[0], nums[1], nums[2]); }
    if num_lens[2] != 4 && num_lens[2] != 2 { return ""; }
    let y = full_year(nums[2], num_lens[2]);
    if order == "mdy" { return iso_from_parts(y, nums[0], nums[1]); }
    if order == "dmy" { return iso_from_parts(y, nums[1], nums[0]); }
    ""
}

// Days since 1970-01-01 for a year, month and day (negative before 1970).
fn days_from_civil(y, m, d) {
    let yy = if m <= 2 { y - 1 } else { y };
    let era = if yy >= 0 { yy / 400 } else { (yy - 399) / 400 };
    let yoe = yy - era * 400;
    let mp = if m > 2 { m - 3 } else { m + 9 };
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

// The YYYY-MM-DD date for a number of days since 1970-01-01.
fn date_from_days(n) {
    let z = n + 719468;
    let era = if z >= 0 { z / 146097 } else { (z - 146096) / 146097 };
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + (if m <= 2 { 1 } else { 0 });
    iso_from_parts(y, m, d)
}

// Converts an Excel date serial number (as Excel stores dates, 45750 = 2025-04-03) to YYYY-MM-DD.
// A time fraction is ignored. Uses Excel's default 1900 date system. Returns "" for values
// below 1, for 60 (Excel's nonexistent 1900-02-29) and for anything that isn't a number.
fn excel_serial_to_iso(v) {
    let t = type_of(v);
    let n = 0;
    if t == "i64" {
        n = v;
    } else if t == "f64" {
        n = v.floor().to_int();
    } else if t == "string" {
        let s = v;
        s.trim();
        if s.len() == 0 { return ""; }
        let dot = s.index_of('.');
        if dot >= 0 { s = s.sub_string(0, dot); }
        for c in s {
            if c < '0' || c > '9' { return ""; }
        }
        n = parse_int(s);
    } else {
        return "";
    }
    if n < 1 || n == 60 || n > 2958465 { return ""; }
    // Serials up to 59 count from 1900-01-01; from 61 on, Excel's extra 1900-02-29 is skipped.
    let base = if n < 60 { days_from_civil(1899, 12, 31) } else { days_from_civil(1899, 12, 30) };
    date_from_days(base + n)
}

// Whole days from date a to date b (both YYYY-MM-DD); negative when b is earlier.
// Returns () when either isn't a valid ISO date.
fn days_between(a, b) {
    if !is_valid_iso_date(a) || !is_valid_iso_date(b) { return (); }
    let da = days_from_civil(parse_int(a.sub_string(0, 4)), parse_int(a.sub_string(5, 2)), parse_int(a.sub_string(8, 2)));
    let db = days_from_civil(parse_int(b.sub_string(0, 4)), parse_int(b.sub_string(5, 2)), parse_int(b.sub_string(8, 2)));
    db - da
}
