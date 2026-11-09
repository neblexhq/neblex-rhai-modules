// Number and money cleanup functions for Neblex Code steps.
// Import the module as "numbers" in a Code step, then call the functions directly,
// for example item.amount = parse_number(item.amount, "auto");
// Every function is pure: it reads its arguments and returns a value. Nothing is sent anywhere.

// Reads a number from text such as "1,234.56", "1.234,56", "$1,234.56", "(500)", "1 234,5",
// "CHF 1'234.50" or "1,234-" (trailing minus, as some ERP exports write negatives).
// `decimal_sep` is "." or "," to say which character marks decimals, or "auto" to decide from
// the text. In "auto", a single separator followed by exactly three digits ("1,234" or "1.234")
// is read as a thousands separator. Currency symbols, codes and units around the number are
// ignored; letters inside it are not. Returns a decimal number, or () when no number can be read.
// Numbers that are already numbers are returned unchanged.
fn parse_number(v, decimal_sep) {
    let t = type_of(v);
    if t == "i64" || t == "f64" { return v; }
    if t != "string" { return (); }
    let chars = [];
    for c in v { chars.push(c); }
    let first = -1;
    let last = -1;
    for i in 0..chars.len() {
        let c = chars[i];
        if c >= '0' && c <= '9' {
            if first < 0 { first = i; }
            last = i;
        }
    }
    if first < 0 { return (); }
    // A leading separator belongs to the number: ".5" is 0.5.
    if first > 0 && (chars[first - 1] == '.' || chars[first - 1] == ',') { first -= 1; }
    let negative = false;
    for i in 0..first {
        if chars[i] == '-' || chars[i] == '(' { negative = true; }
    }
    for i in (last + 1)..chars.len() {
        if chars[i] == '-' { negative = true; }
    }
    // The number itself: digits and separators. Spaces and apostrophes are thousands separators.
    let body = "";
    let dots = 0;
    let commas = 0;
    for i in first..(last + 1) {
        let c = chars[i];
        if c >= '0' && c <= '9' {
            body += c;
        } else if c == '.' {
            body += c;
            dots += 1;
        } else if c == ',' {
            body += c;
            commas += 1;
        } else if c == ' ' || c == '\'' {
            continue;
        } else {
            return ();
        }
    }
    let dec = decimal_sep;
    if dec != "." && dec != "," {
        if dots > 0 && commas > 0 {
            // The separator that appears last marks the decimals.
            let last_dot = -1;
            let last_comma = -1;
            let i = 0;
            for c in body {
                if c == '.' { last_dot = i; }
                if c == ',' { last_comma = i; }
                i += 1;
            }
            dec = if last_dot > last_comma { "." } else { "," };
        } else if dots + commas == 0 {
            dec = ".";
        } else {
            let sep = if dots > 0 { "." } else { "," };
            let other = if dots > 0 { "," } else { "." };
            if dots + commas > 1 {
                dec = other;
            } else {
                let idx = body.index_of(sep);
                let after = body.len() - idx - 1;
                let int_part = body.sub_string(0, idx);
                dec = if after == 3 && int_part != "0" && int_part != "" { other } else { sep };
            }
        }
    }
    let out = "";
    let dec_count = 0;
    for c in body {
        if c >= '0' && c <= '9' {
            out += c;
        } else if c.to_string() == dec {
            out += ".";
            dec_count += 1;
        }
    }
    if dec_count > 1 { return (); }
    if out.starts_with(".") { out = "0" + out; }
    if out.ends_with(".") { out += "0"; }
    let x = parse_float(out);
    if negative { -x } else { x }
}

// Reads a percentage as a fraction: "12.5%" -> 0.125, "7 %" -> 0.07. Text without a % sign
// is read as a plain number and returned as is ("0.125" -> 0.125). Returns () when unreadable.
fn parse_percent(v, decimal_sep) {
    let x = parse_number(v, decimal_sep);
    if type_of(x) == "()" { return (); }
    if type_of(v) == "string" && v.contains('%') { return x.to_float() / 100.0; }
    x
}

// Converts an amount to whole cents (or the smallest unit of a two-decimal currency):
// "$1,234.56" -> 123456. Rounds to the nearest cent. Returns () when unreadable.
fn to_cents(v, decimal_sep) {
    let x = parse_number(v, decimal_sep);
    if type_of(x) == "()" { return (); }
    (x.to_float() * 100.0).round().to_int()
}

// The ISO 4217 currency code in an amount such as "EUR 1.234,56", "£12", "R$ 50" or
// "1,200 usd". A plain "$" is ambiguous, so it returns `dollar_default` (for example "USD").
// Returns "" when no currency is found.
fn currency_code(v, dollar_default) {
    if type_of(v) != "string" { return ""; }
    let codes = [
        "USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD", "CNY", "INR", "MXN", "BRL",
        "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "ZAR", "SGD", "HKD", "KRW", "AED", "SAR",
        "ILS", "TRY"
    ];
    // Three-letter codes written as a separate word.
    let word = "";
    for c in v + " " {
        if c.to_upper() != c.to_lower() {
            word += c;
        } else {
            if word.len() == 3 && codes.contains(word.to_upper()) { return word.to_upper(); }
            word = "";
        }
    }
    // Symbols, longest first so "R$" isn't read as "$".
    let symbols = [
        ["US$", "USD"], ["CA$", "CAD"], ["C$", "CAD"], ["A$", "AUD"], ["NZ$", "NZD"],
        ["R$", "BRL"], ["HK$", "HKD"], ["S$", "SGD"], ["€", "EUR"], ["£", "GBP"],
        ["¥", "JPY"], ["₹", "INR"], ["₩", "KRW"], ["₪", "ILS"], ["₺", "TRY"], ["zł", "PLN"]
    ];
    for pair in symbols {
        if v.contains(pair[0]) { return pair[1]; }
    }
    if v.contains('$') { return dollar_default; }
    ""
}

// Rounds to `places` decimals with ties going to the even digit (banker's rounding), as many
// accounting and tax rules require: 2.345 -> 2.34, 2.355 -> 2.36, 2.5 to 0 places -> 2.0.
// Reads text the way parse_number does with "auto". Returns () when no number can be read.
fn round_half_even(v, places) {
    let x = parse_number(v, "auto");
    if type_of(x) == "()" { return (); }
    let f = 1.0;
    for i in 0..places { f *= 10.0; }
    let scaled = x.to_float() * f;
    let lower = scaled.floor();
    let diff = scaled - lower;
    // Values within a tiny margin of .5 count as ties, so 2.345 (stored as 2.34499999...) still ties.
    let rounded = if diff > 0.5 + 0.000000001 {
        lower + 1.0
    } else if diff < 0.5 - 0.000000001 {
        lower
    } else if lower % 2.0 == 0.0 {
        lower
    } else {
        lower + 1.0
    };
    rounded / f
}

// Formats a number for display with `places` decimals and thousands separators, in a `style`:
// "us" -> "1,234.50", "eu" -> "1.234,50", "fr" -> "1 234,50", "ch" -> "1'234.50", "plain" -> "1234.50".
// Rounds halves away from zero. Reads text the way parse_number does with "auto".
// Returns "" when no number can be read.
fn format_number(v, places, style) {
    let x = parse_number(v, "auto");
    if type_of(x) == "()" { return ""; }
    let neg = x < 0;
    let a = if neg { -x.to_float() } else { x.to_float() };
    let f = 1;
    for i in 0..places { f *= 10; }
    let units = (a * f.to_float()).round().to_int();
    let int_part = (units / f).to_string();
    let frac = (units % f).to_string();
    while frac.len() < places { frac = "0" + frac; }
    let group = switch style { "eu" => ".", "fr" => " ", "ch" => "'", "plain" => "", _ => "," };
    let dec = switch style { "eu" => ",", "fr" => ",", _ => "." };
    let grouped = "";
    let n = int_part.len();
    let i = 0;
    for c in int_part {
        if i > 0 && (n - i) % 3 == 0 { grouped += group; }
        grouped += c;
        i += 1;
    }
    let out = if places > 0 { grouped + dec + frac } else { grouped };
    if neg && units > 0 { "-" + out } else { out }
}

// The change from `before` to `after` as a fraction: 80 -> 100 is 0.25 (25%), 100 -> 80 is -0.2.
// Returns () when either value can't be read or `before` is 0.
fn percent_change(before, after) {
    let a = parse_number(before, "auto");
    let b = parse_number(after, "auto");
    if type_of(a) == "()" || type_of(b) == "()" || a == 0 { return (); }
    (b.to_float() - a.to_float()) / a.to_float().abs()
}

// `a` divided by `b` as a decimal number, or `fallback` when `b` is 0 or either value can't be
// read: safe_divide(10, 4, 0) -> 2.5, safe_divide(10, 0, 0) -> 0.
fn safe_divide(a, b, fallback) {
    let x = parse_number(a, "auto");
    let y = parse_number(b, "auto");
    if type_of(x) == "()" || type_of(y) == "()" || y == 0 { return fallback; }
    x.to_float() / y.to_float()
}
