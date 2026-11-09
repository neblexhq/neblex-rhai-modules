// Text functions for Neblex Code steps.
// Import the module as "text" in a Code step, then call the functions directly,
// for example item.slug = slugify(item.product_name);
// Every function is pure: it reads its arguments and returns a value. Nothing is sent anywhere.

// Replaces accented Latin letters with their plain form: "Müller" -> "Muller", "Ærø" -> "AEro",
// "straße" -> "strasse". Other characters are kept. Values that aren't text are returned unchanged.
fn remove_accents(v) {
    if type_of(v) != "string" { return v; }
    let from = "ÀÁÂÃÄÅĀĂĄàáâãäåāăąÇĆČçćčĎĐďđÈÉÊËĒĖĘĚèéêëēėęěĞğÌÍÎÏĪĮİìíîïīįıĹĽŁĺľłÑŃŇñńňÒÓÔÕÖØŌŐòóôõöøōőŔŘŕřŚŠŞśšşŤťÙÚÛÜŪŮŰŲùúûüūůűųÝŸýÿŹŻŽźżž";
    let to   = "AAAAAAAAAaaaaaaaaaCCCcccDDddEEEEEEEEeeeeeeeeGgIIIIIIIiiiiiiiLLLlllNNNnnnOOOOOOOOooooooooRRrrSSSsssTtUUUUUUUUuuuuuuuuYYyyZZZzzz";
    let out = "";
    for c in v {
        let i = from.index_of(c);
        if i >= 0 {
            out += to[i];
        } else if c == 'ß' {
            out += "ss";
        } else if c == 'Æ' {
            out += "AE";
        } else if c == 'æ' {
            out += "ae";
        } else if c == 'Œ' {
            out += "OE";
        } else if c == 'œ' {
            out += "oe";
        } else if c == 'Þ' {
            out += "Th";
        } else if c == 'þ' {
            out += "th";
        } else {
            out += c;
        }
    }
    out
}

// A lowercase, URL-safe version of the text: accents removed, anything other than letters and
// digits turned into single hyphens. "Café Crème 2.0!" -> "cafe-creme-2-0". Missing values become "".
fn slugify(v) {
    if type_of(v) == "()" { return ""; }
    let s = remove_accents(v.to_string()).to_lower();
    let out = "";
    let hyphen = false;
    for c in s {
        if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') {
            if hyphen && out.len() > 0 { out += "-"; }
            out += c;
            hyphen = false;
        } else {
            hyphen = true;
        }
    }
    out
}

// Shortens text to at most `max_chars` characters, cutting at a space and adding "..." when
// anything was removed (the "..." counts toward the limit). A first word longer than the limit is
// cut mid-word. Text that already fits is returned unchanged.
fn truncate_words(v, max_chars) {
    if type_of(v) != "string" { return v; }
    if v.len() <= max_chars { return v; }
    if max_chars <= 3 { return v.sub_string(0, max_chars); }
    let room = max_chars - 3;
    let cut = v.sub_string(0, room);
    // Back up to the last space unless the next character already starts a new word.
    if v[room] != ' ' {
        let last_space = -1;
        let i = 0;
        for c in cut {
            if c == ' ' { last_space = i; }
            i += 1;
        }
        if last_space > 0 { cut = cut.sub_string(0, last_space); }
    }
    cut.trim();
    cut + "..."
}

// The first letter of each word, uppercased: "jane ann doe" -> "JAD", "Mary-Jane Smith" -> "MJS".
// Missing values become "".
fn initials(v) {
    if type_of(v) == "()" { return ""; }
    let out = "";
    let at_start = true;
    for c in v.to_string() {
        if c == ' ' || c == '-' || c == '\t' || c == '.' {
            at_start = true;
        } else {
            if at_start && c.to_upper() != c.to_lower() { out += c.to_upper(); }
            at_start = false;
        }
    }
    out
}

// Replaces the middle of a value with "*", keeping `keep_start` characters at the start and
// `keep_end` at the end: mask_middle("4111111111111111", 0, 4) -> "************1111".
// When the value is too short to keep both ends, every character is masked. Missing values become "".
fn mask_middle(v, keep_start, keep_end) {
    if type_of(v) == "()" { return ""; }
    let s = v.to_string();
    let n = s.len();
    let out = "";
    let i = 0;
    for c in s {
        if n > keep_start + keep_end && (i < keep_start || i >= n - keep_end) {
            out += c;
        } else {
            out += "*";
        }
        i += 1;
    }
    out
}

// Pads a value on the left to `width` characters with `pad` (one character), for fixed-length
// codes: pad_left(42, 6, "0") -> "000042". Longer values are returned unchanged. Missing values become "".
fn pad_left(v, width, pad) {
    if type_of(v) == "()" { return ""; }
    let s = v.to_string();
    let p = if type_of(pad) == "string" && pad.len() > 0 { pad.sub_string(0, 1) } else { " " };
    while s.len() < width { s = p + s; }
    s
}

// Plain text from a snippet of HTML: tags removed (each becomes a space), common entities decoded
// (&amp; &lt; &gt; &quot; &apos; &nbsp;, and numeric entities for printable ASCII and &#160;) and
// whitespace collapsed. Other entities are left as written. Meant for short fields such as
// descriptions, not whole web pages.
fn strip_html(v) {
    if type_of(v) != "string" { return v; }
    let text = "";
    let in_tag = false;
    for c in v {
        if c == '<' {
            in_tag = true;
            text += " ";
        } else if c == '>' && in_tag {
            in_tag = false;
        } else if !in_tag {
            text += c;
        }
    }
    let out = "";
    let i = 0;
    let n = text.len();
    while i < n {
        let c = text[i];
        let done = false;
        if c == '&' {
            let semi = -1;
            let j = i + 1;
            while j < n && j <= i + 10 {
                if text[j] == ';' { semi = j; break; }
                j += 1;
            }
            if semi > 0 {
                let name = text.sub_string(i + 1, semi - i - 1);
                let rep = switch name {
                    "amp" => "&",
                    "lt" => "<",
                    "gt" => ">",
                    "quot" => "\"",
                    "apos" => "'",
                    "#39" => "'",
                    "nbsp" => " ",
                    _ => ()
                };
                // Numeric entities for printable ASCII (&#34; &#x27;) and the no-break space (&#160;).
                if type_of(rep) == "()" && name.starts_with("#") && name.len() > 1 {
                    let hex = name.starts_with("#x") || name.starts_with("#X");
                    let digits = if hex { name.sub_string(2) } else { name.sub_string(1) };
                    let ok = digits.len() > 0 && digits.len() <= 6;
                    for d in digits {
                        let is_dec = d >= '0' && d <= '9';
                        let is_hex = (d >= 'a' && d <= 'f') || (d >= 'A' && d <= 'F');
                        if !(is_dec || (hex && is_hex)) { ok = false; }
                    }
                    let num = if !ok { -1 } else if hex { parse_int(digits, 16) } else { parse_int(digits) };
                    let ascii = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
                    if num >= 32 && num <= 126 { rep = ascii[num - 32].to_string(); }
                    if num == 160 { rep = " "; }
                }
                if type_of(rep) != "()" {
                    out += rep;
                    i = semi + 1;
                    done = true;
                }
            }
        }
        if !done {
            out += c;
            i += 1;
        }
    }
    // Collapse whitespace.
    let result = "";
    let space = false;
    for c in out {
        if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
            space = true;
        } else {
            if space && result.len() > 0 { result += " "; }
            result += c;
            space = false;
        }
    }
    result
}

// The number of words: runs of characters separated by whitespace. Missing values give 0.
fn word_count(v) {
    if type_of(v) == "()" { return 0; }
    let count = 0;
    let in_word = false;
    for c in v.to_string() {
        if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
            in_word = false;
        } else if !in_word {
            in_word = true;
            count += 1;
        }
    }
    count
}
