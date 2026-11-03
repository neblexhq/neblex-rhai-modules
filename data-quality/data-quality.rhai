// Data quality functions for Neblex Code steps.
// Import the module as "data-quality" in a Code step, then call the functions directly,
// for example item.email = normalize_email(item.email);
// Every function is pure: it reads its arguments and returns a value. Nothing is sent anywhere.

// ---------- Text ----------

// True when a value is missing, empty or only whitespace.
fn is_blank(v) {
    if type_of(v) == "()" { return true; }
    if type_of(v) == "string" {
        let s = v;
        s.trim();
        return s.len() == 0;
    }
    false
}

// Trims the text and collapses runs of spaces, tabs and line breaks into one space.
// Values that aren't text are returned unchanged.
fn clean_text(v) {
    if type_of(v) != "string" { return v; }
    let out = "";
    let pending_space = false;
    for c in v {
        if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
            pending_space = true;
        } else {
            if pending_space && out.len() > 0 { out += " "; }
            out += c;
            pending_space = false;
        }
    }
    out
}

// Keeps only the digits 0-9. Missing values become "".
fn digits_only(v) {
    if type_of(v) == "()" { return ""; }
    let out = "";
    for c in v.to_string() {
        if c >= '0' && c <= '9' { out += c; }
    }
    out
}

// ---------- Email ----------

// Trims, lowercases and removes a leading "mailto:" and surrounding angle brackets.
fn normalize_email(v) {
    if type_of(v) != "string" { return ""; }
    let e = v;
    e.trim();
    e = e.to_lower();
    if e.starts_with("mailto:") { e = e.sub_string(7); }
    e.replace("<", "");
    e.replace(">", "");
    e.trim();
    e
}

// Checks that a domain looks like a real host name: labels of letters, digits and hyphens,
// separated by dots, with a top-level domain of at least two letters.
fn is_valid_domain(d) {
    if type_of(d) != "string" { return false; }
    if d.len() < 4 || d.len() > 253 { return false; }
    if !d.contains('.') || d.contains("..") { return false; }
    let labels = d.split(".");
    for l in labels {
        if l.len() == 0 || l.len() > 63 { return false; }
        if l.starts_with("-") || l.ends_with("-") { return false; }
        for c in l {
            if !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-') { return false; }
        }
    }
    let tld = labels[labels.len() - 1];
    if tld.len() < 2 { return false; }
    for c in tld {
        if c >= '0' && c <= '9' { return false; }
    }
    true
}

// Structural email check: one @, a sensible local part and a valid domain.
// It doesn't prove the mailbox exists. International (non-ASCII) addresses return false.
fn is_valid_email(v) {
    let e = normalize_email(v);
    if e.len() < 6 || e.len() > 254 { return false; }
    let parts = e.split("@");
    if parts.len() != 2 { return false; }
    let local = parts[0];
    if local.len() == 0 || local.len() > 64 { return false; }
    if local.starts_with(".") || local.ends_with(".") || local.contains("..") { return false; }
    for c in local {
        let ok = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || "._%+-'".contains(c);
        if !ok { return false; }
    }
    is_valid_domain(parts[1])
}

// The part after the @, lowercased. "" when there is no @.
fn email_domain(v) {
    let e = normalize_email(v);
    let i = e.index_of('@');
    if i < 0 { return ""; }
    e.sub_string(i + 1)
}

// True for addresses at common free mail providers (gmail.com, outlook.com and so on).
// Useful to tell a personal address from a work address before matching to a company.
fn is_free_email(v) {
    let d = email_domain(v);
    let free = [
        "gmail.com", "googlemail.com", "yahoo.com", "ymail.com", "yahoo.co.uk", "outlook.com",
        "hotmail.com", "hotmail.co.uk", "live.com", "msn.com", "icloud.com", "me.com", "mac.com",
        "aol.com", "proton.me", "protonmail.com", "gmx.com", "gmx.de", "gmx.net", "web.de",
        "mail.com", "zoho.com", "yandex.com", "yandex.ru", "qq.com", "163.com", "fastmail.com",
        "hey.com", "comcast.net", "verizon.net", "att.net", "sbcglobal.net", "btinternet.com"
    ];
    free.contains(d)
}

// True for shared role addresses such as info@, sales@ or noreply@, which rarely belong to one person.
fn is_role_email(v) {
    let e = normalize_email(v);
    let i = e.index_of('@');
    if i <= 0 { return false; }
    let local = e.sub_string(0, i);
    let plus = local.index_of('+');
    if plus > 0 { local = local.sub_string(0, plus); }
    let roles = [
        "info", "sales", "support", "admin", "contact", "hello", "office", "billing", "accounts",
        "accounting", "noreply", "no-reply", "donotreply", "marketing", "team", "help", "hr",
        "jobs", "careers", "webmaster", "postmaster", "orders", "service", "enquiries", "inquiries"
    ];
    roles.contains(local)
}

// A key for finding duplicate people by email: lowercased, "+tag" removed, and for Gmail the
// dots in the name removed (Gmail ignores them), with googlemail.com treated as gmail.com.
fn email_match_key(v) {
    let e = normalize_email(v);
    let i = e.index_of('@');
    if i <= 0 { return e; }
    let local = e.sub_string(0, i);
    let domain = e.sub_string(i + 1);
    let plus = local.index_of('+');
    if plus > 0 { local = local.sub_string(0, plus); }
    if domain == "googlemail.com" { domain = "gmail.com"; }
    if domain == "gmail.com" { local.replace(".", ""); }
    local + "@" + domain
}

// ---------- Phone ----------

// Formats a phone number as E.164 (+14155550123). default_cc is the country calling code to use
// when the number has no + or 00 prefix, for example "1" for the US and Canada or "44" for the UK.
// Extensions (ext, x, #) are dropped. Returns "" when the number can't be a valid phone number.
fn phone_e164(v, default_cc) {
    if is_blank(v) { return ""; }
    let s = v.to_string();
    s.trim();
    let lower = s.to_lower();
    let cut = -1;
    for m in ["ext", "x", "#"] {
        let i = lower.index_of(m);
        if i >= 0 && (cut < 0 || i < cut) { cut = i; }
    }
    if cut == 0 { return ""; }
    if cut > 0 { s = s.sub_string(0, cut); }
    let international = s.starts_with("+");
    let digits = digits_only(s);
    if !international && digits.starts_with("00") {
        digits = digits.sub_string(2);
        international = true;
    }
    let number = "";
    if international {
        number = digits;
    } else {
        let cc = digits_only(default_cc);
        if cc == "1" {
            if digits.len() == 11 && digits.starts_with("1") {
                number = digits;
            } else if digits.len() == 10 {
                number = "1" + digits;
            } else {
                return "";
            }
        } else {
            if digits.starts_with("0") { digits = digits.sub_string(1); }
            number = cc + digits;
        }
    }
    if number.len() < 8 || number.len() > 15 || number.starts_with("0") { return ""; }
    // US and Canada: area code and exchange can't start with 0 or 1.
    if number.starts_with("1") {
        if number.len() != 11 { return ""; }
        let area = number.sub_string(1, 1);
        let exchange = number.sub_string(4, 1);
        if area == "0" || area == "1" || exchange == "0" || exchange == "1" { return ""; }
    }
    "+" + number
}

// ---------- Names ----------

// Capitalizes each part of a person's name: "o'NEIL" becomes "O'Neil", "mary-jane" becomes
// "Mary-Jane" and "mcdonald" becomes "McDonald". Particles such as "van" or "de" are capitalized too.
fn title_case_name(v) {
    if type_of(v) != "string" { return v; }
    let s = clean_text(v).to_lower();
    let out = "";
    let cap = true;
    let word = "";
    for c in s {
        if cap { out += c.to_upper(); } else { out += c; }
        if c == ' ' || c == '-' || c == '\'' {
            cap = true;
            word = "";
        } else {
            word += c;
            cap = word == "mc";
        }
    }
    out
}

// Splits a full name into first_name and last_name. Handles "Last, First".
// Everything after the first word becomes the last name ("Ana de la Cruz" -> "Ana" / "de la Cruz").
fn split_full_name(v) {
    let s = clean_text(v);
    if type_of(s) != "string" || s.len() == 0 { return #{ first_name: "", last_name: "" }; }
    let comma = s.index_of(',');
    if comma >= 0 {
        let last = clean_text(s.sub_string(0, comma));
        let first = clean_text(s.sub_string(comma + 1));
        return #{ first_name: first, last_name: last };
    }
    let space = s.index_of(' ');
    if space < 0 { return #{ first_name: s, last_name: "" }; }
    #{ first_name: s.sub_string(0, space), last_name: s.sub_string(space + 1) }
}

// ---------- Companies and domains ----------

// A key for matching company names: lowercase, "&" read as "and", punctuation removed,
// a leading "the" and trailing legal forms (Inc, LLC, Ltd, GmbH & Co. KG, ...) dropped.
// "The Acme Company, Inc." and "ACME Co" both become "acme".
fn company_match_key(v) {
    if type_of(v) != "string" { return ""; }
    let s = v.to_lower();
    s.replace("&", " and ");
    let plain = "";
    for c in s {
        if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == ' ' {
            plain += c;
        } else if c == '-' || c == '/' {
            plain += " ";
        } else if c.to_upper() != c {
            plain += c;
        }
    }
    let words = clean_text(plain).split(" ");
    let legal = [
        "inc", "incorporated", "llc", "ltd", "limited", "corp", "corporation", "co", "company",
        "plc", "gmbh", "ag", "sa", "sas", "srl", "bv", "nv", "pty", "lp", "llp", "pllc", "oy",
        "ab", "kg", "sarl", "spa", "se"
    ];
    if words.len() > 1 && words[0] == "the" { words.remove(0); }
    // "and" is dropped too when it ends up last, so "Müller GmbH & Co. KG" becomes "müller".
    while words.len() > 1 && (legal.contains(words[words.len() - 1]) || words[words.len() - 1] == "and") {
        words.pop();
    }
    let out = "";
    for w in words {
        if w == "" { continue; }
        if out.len() > 0 { out += " "; }
        out += w;
    }
    out
}

// The host name from a website or email address: "https://www.Acme.com/about?x=1" and
// "jane@acme.com" both give "acme.com". Useful for matching contacts to accounts.
fn domain_from_url(v) {
    if type_of(v) != "string" { return ""; }
    let s = v;
    s.trim();
    s = s.to_lower();
    let at = s.index_of('@');
    if at >= 0 { s = s.sub_string(at + 1); }
    let scheme = s.index_of("://");
    if scheme >= 0 { s = s.sub_string(scheme + 3); }
    if s.starts_with("//") { s = s.sub_string(2); }
    let end = s.len();
    for m in ["/", "?", "#", ":"] {
        let i = s.index_of(m);
        if i >= 0 && i < end { end = i; }
    }
    s = s.sub_string(0, end);
    if s.starts_with("www.") { s = s.sub_string(4); }
    if s.ends_with(".") { s = s.sub_string(0, s.len() - 1); }
    s
}

// ---------- US addresses ----------

// Formats a US ZIP code as 12345 or 12345-6789. Restores a leading zero that a spreadsheet
// dropped (2134 -> 02134). Returns "" when it can't be a ZIP code.
fn us_zip(v) {
    let d = digits_only(v);
    if d.len() == 4 || d.len() == 8 { d = "0" + d; }
    if d.len() == 5 { return d; }
    if d.len() == 9 { return d.sub_string(0, 5) + "-" + d.sub_string(5); }
    ""
}

// The two-letter code for a US state, DC or Puerto Rico, from its name or code
// ("new york", "N.Y.", "ny" -> "NY"). Returns "" when it isn't recognized.
fn us_state_code(v) {
    if type_of(v) != "string" { return ""; }
    let k = clean_text(v).to_lower();
    k.replace(".", "");
    let states = #{
        "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR", "california": "CA",
        "colorado": "CO", "connecticut": "CT", "delaware": "DE", "district of columbia": "DC",
        "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID", "illinois": "IL",
        "indiana": "IN", "iowa": "IA", "kansas": "KS", "kentucky": "KY", "louisiana": "LA",
        "maine": "ME", "maryland": "MD", "massachusetts": "MA", "michigan": "MI", "minnesota": "MN",
        "mississippi": "MS", "missouri": "MO", "montana": "MT", "nebraska": "NE", "nevada": "NV",
        "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
        "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK", "oregon": "OR",
        "pennsylvania": "PA", "puerto rico": "PR", "rhode island": "RI", "south carolina": "SC",
        "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT", "vermont": "VT",
        "virginia": "VA", "washington": "WA", "west virginia": "WV", "wisconsin": "WI", "wyoming": "WY"
    };
    if states.contains(k) { return states[k]; }
    let code = k.to_upper();
    if code.len() == 2 && states.values().contains(code) { return code; }
    ""
}

// ---------- Records ----------

// The names of the fields in `fields` that are missing or blank on the record.
// missing_fields(item, ["email", "company"]) -> ["company"]
fn missing_fields(record, fields) {
    let out = [];
    for f in fields {
        if is_blank(record[f]) { out.push(f); }
    }
    out
}

// Share of the listed fields that are filled in, from 0.0 to 1.0, rounded to two decimals.
fn completeness(record, fields) {
    if fields.len() == 0 { return 1.0; }
    let filled = fields.len() - missing_fields(record, fields).len();
    ((filled.to_float() / fields.len().to_float()) * 100.0).round() / 100.0
}
