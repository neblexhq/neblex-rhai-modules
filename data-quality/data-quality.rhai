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

// ---------- Countries, URLs and check digits ----------

// The ISO 3166-1 two-letter code for a country written as a name, a common variant or a
// two- or three-letter code: "United States", "U.S.A." and "USA" -> "US", "Deutschland" -> "DE",
// "UK" and "England" -> "GB". Covers about 60 countries most common in business data.
// Returns "" when the country isn't recognized.
fn country_code(v) {
    if type_of(v) != "string" { return ""; }
    // Lowercase, keep letters and spaces, collapse spaces, drop a leading "the ".
    let k = "";
    let space = false;
    for c in v.to_lower() {
        if c.to_upper() != c.to_lower() {
            if space && k.len() > 0 { k += " "; }
            k += c;
            space = false;
        } else if c == ' ' || c == '-' || c == ',' || c == '\t' {
            space = true;
        }
    }
    if k.starts_with("the ") { k = k.sub_string(4); }
    if k.len() == 0 { return ""; }
    let table = [
        ["US", "usa", "united states", "united states of america", "america", "us"],
        ["GB", "gbr", "united kingdom", "uk", "great britain", "britain", "england", "scotland", "wales", "northern ireland", "gb"],
        ["CA", "can", "canada", "ca"],
        ["MX", "mex", "mexico", "méxico", "mx"],
        ["DE", "deu", "germany", "deutschland", "de"],
        ["FR", "fra", "france", "fr"],
        ["ES", "esp", "spain", "españa", "espana", "es"],
        ["IT", "ita", "italy", "italia", "it"],
        ["NL", "nld", "netherlands", "holland", "nederland", "nl"],
        ["BE", "bel", "belgium", "belgië", "belgique", "be"],
        ["LU", "lux", "luxembourg", "lu"],
        ["CH", "che", "switzerland", "schweiz", "suisse", "svizzera", "ch"],
        ["AT", "aut", "austria", "österreich", "osterreich", "at"],
        ["IE", "irl", "ireland", "republic of ireland", "ie"],
        ["PT", "prt", "portugal", "pt"],
        ["SE", "swe", "sweden", "sverige", "se"],
        ["NO", "nor", "norway", "norge", "no"],
        ["DK", "dnk", "denmark", "danmark", "dk"],
        ["FI", "fin", "finland", "suomi", "fi"],
        ["IS", "isl", "iceland", "is"],
        ["PL", "pol", "poland", "polska", "pl"],
        ["CZ", "cze", "czech republic", "czechia", "cz"],
        ["SK", "svk", "slovakia", "sk"],
        ["HU", "hun", "hungary", "hu"],
        ["RO", "rou", "romania", "ro"],
        ["BG", "bgr", "bulgaria", "bg"],
        ["GR", "grc", "greece", "gr"],
        ["HR", "hrv", "croatia", "hr"],
        ["SI", "svn", "slovenia", "si"],
        ["EE", "est", "estonia", "ee"],
        ["LV", "lva", "latvia", "lv"],
        ["LT", "ltu", "lithuania", "lt"],
        ["UA", "ukr", "ukraine", "ua"],
        ["TR", "tur", "turkey", "türkiye", "turkiye", "tr"],
        ["IL", "isr", "israel", "il"],
        ["AE", "are", "united arab emirates", "uae", "ae"],
        ["SA", "sau", "saudi arabia", "sa"],
        ["EG", "egy", "egypt", "eg"],
        ["ZA", "zaf", "south africa", "za"],
        ["NG", "nga", "nigeria", "ng"],
        ["KE", "ken", "kenya", "ke"],
        ["MA", "mar", "morocco", "ma"],
        ["IN", "ind", "india", "in"],
        ["CN", "chn", "china", "peoples republic of china", "prc", "cn"],
        ["HK", "hkg", "hong kong", "hk"],
        ["TW", "twn", "taiwan", "tw"],
        ["JP", "jpn", "japan", "jp"],
        ["KR", "kor", "south korea", "korea", "republic of korea", "kr"],
        ["SG", "sgp", "singapore", "sg"],
        ["MY", "mys", "malaysia", "my"],
        ["TH", "tha", "thailand", "th"],
        ["VN", "vnm", "vietnam", "viet nam", "vn"],
        ["PH", "phl", "philippines", "ph"],
        ["ID", "idn", "indonesia", "id"],
        ["AU", "aus", "australia", "au"],
        ["NZ", "nzl", "new zealand", "nz"],
        ["BR", "bra", "brazil", "brasil", "br"],
        ["AR", "arg", "argentina", "ar"],
        ["CL", "chl", "chile", "cl"],
        ["CO", "col", "colombia", "co"],
        ["PE", "per", "peru", "perú", "pe"],
        ["CR", "cri", "costa rica", "cr"],
        ["PR", "pri", "puerto rico", "pr"]
    ];
    // "U.S." and "U.K." arrive as single letters separated by spaces after cleanup.
    let joined = k;
    joined.replace(" ", "");
    for row in table {
        for i in 1..row.len() {
            if row[i] == k || (joined.len() <= 3 && row[i] == joined) { return row[0]; }
        }
    }
    ""
}

// True for a well-formed http or https web address with a real-looking host name:
// "https://www.acme.com/pricing?x=1" -> true, "acme.com" -> false (no scheme),
// "http://localhost:8080" -> false. It doesn't check that the site exists.
fn is_valid_url(v) {
    if type_of(v) != "string" { return false; }
    let s = v;
    s.trim();
    let lower = s.to_lower();
    let rest = if lower.starts_with("https://") { lower.sub_string(8) } else if lower.starts_with("http://") { lower.sub_string(7) } else { return false; };
    for c in rest {
        if c == ' ' || c == '\t' || c == '"' || c == '<' || c == '>' { return false; }
    }
    // The host ends at the first /, ? or #; drop a port and user info.
    let end = rest.len();
    let i = 0;
    for c in rest {
        if c == '/' || c == '?' || c == '#' { end = i; break; }
        i += 1;
    }
    let host = rest.sub_string(0, end);
    let at = host.index_of('@');
    if at >= 0 { host = host.sub_string(at + 1); }
    let colon = host.index_of(':');
    if colon >= 0 {
        let port = host.sub_string(colon + 1);
        if port.len() == 0 || port.len() > 5 { return false; }
        for c in port {
            if c < '0' || c > '9' { return false; }
        }
        if parse_int(port) > 65535 { return false; }
        host = host.sub_string(0, colon);
    }
    is_valid_domain(host)
}

// True when a number passes the Luhn check digit, used by payment cards, IMEI numbers and many
// account numbers. Spaces and hyphens are ignored; any other non-digit makes it false, and so does
// a number shorter than 2 digits.
fn luhn_valid(v) {
    if type_of(v) == "()" { return false; }
    let digits = [];
    for c in v.to_string() {
        if c >= '0' && c <= '9' {
            digits.push(c.to_int() - 48);
        } else if c != ' ' && c != '-' {
            return false;
        }
    }
    if digits.len() < 2 { return false; }
    let sum = 0;
    let double = false;
    let i = digits.len() - 1;
    while i >= 0 {
        let d = digits[i];
        if double {
            d *= 2;
            if d > 9 { d -= 9; }
        }
        sum += d;
        double = !double;
        i -= 1;
    }
    sum % 10 == 0
}

// ---------- Postcodes outside the US ----------

// A Canadian postal code as "A1A 1A1": "v6b4n8" -> "V6B 4N8". Returns "" when it can't be one
// (wrong pattern, or letters Canada Post doesn't use: D, F, I, O, Q, U, and W or Z first).
fn ca_postal_code(v) {
    if type_of(v) == "()" { return ""; }
    let s = "";
    for c in v.to_string().to_upper() {
        if c != ' ' && c != '-' { s += c; }
    }
    if s.len() != 6 { return ""; }
    let banned = "DFIOQU";
    for i in 0..6 {
        let c = s[i];
        let letter = c >= 'A' && c <= 'Z';
        let digit = c >= '0' && c <= '9';
        if i % 2 == 0 {
            if !letter || banned.contains(c) { return ""; }
        } else if !digit {
            return "";
        }
    }
    if s[0] == 'W' || s[0] == 'Z' { return ""; }
    s.sub_string(0, 3) + " " + s.sub_string(3)
}

// A UK postcode as "OUTWARD INWARD": "sw1a1aa" -> "SW1A 1AA", "m1 1ae" -> "M1 1AE". Checks the
// standard shapes (A9, A99, AA9, AA99, A9A, AA9A, then 9AA). Returns "" when it can't be one.
// It checks the format only, not that the postcode exists.
fn uk_postcode(v) {
    if type_of(v) == "()" { return ""; }
    let s = "";
    for c in v.to_string().to_upper() {
        if c != ' ' && c != '-' { s += c; }
    }
    if s == "GIR0AA" { return "GIR 0AA"; }
    if s.len() < 5 || s.len() > 7 { return ""; }
    let outward = s.sub_string(0, s.len() - 3);
    let inward = s.sub_string(s.len() - 3);
    // Inward: a digit, then two letters other than C, I, K, M, O, V.
    if inward[0] < '0' || inward[0] > '9' { return ""; }
    for i in 1..3 {
        let c = inward[i];
        if c < 'A' || c > 'Z' || "CIKMOV".contains(c) { return ""; }
    }
    // Outward shape as a pattern of L (letter) and D (digit).
    let shape = "";
    for c in outward {
        shape += if c >= 'A' && c <= 'Z' { "L" } else if c >= '0' && c <= '9' { "D" } else { "?" };
    }
    if !["LD", "LDD", "LLD", "LLDD", "LDL", "LLDL"].contains(shape) { return ""; }
    outward + " " + inward
}

// True for addresses at common disposable (throwaway) email services, such as mailinator.com or
// 10minutemail.com, including their subdomains. The list covers well-known services, not all of them.
fn is_disposable_email(v) {
    let d = email_domain(v);
    if d == "" { return false; }
    let disposable = [
        "mailinator.com", "guerrillamail.com", "guerrillamail.net", "sharklasers.com", "10minutemail.com",
        "tempmail.com", "temp-mail.org", "tempmail.net", "yopmail.com", "trashmail.com", "getnada.com",
        "dispostable.com", "maildrop.cc", "throwawaymail.com", "fakeinbox.com", "mailnesia.com",
        "mintemail.com", "emailondeck.com", "mohmal.com", "tempr.email", "discard.email", "spamgourmet.com",
        "mailcatch.com", "moakt.com", "burnermail.io", "inboxkitten.com", "tempinbox.com", "33mail.com"
    ];
    for x in disposable {
        if d == x || d.ends_with("." + x) { return true; }
    }
    false
}
