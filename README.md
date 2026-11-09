# Neblex Rhai modules

[![Tests](https://github.com/neblexhq/neblex-rhai-modules/actions/workflows/test.yml/badge.svg)](https://github.com/neblexhq/neblex-rhai-modules/actions/workflows/test.yml)

Reusable [Rhai](https://www.neblex.com/integration-fabric/docs/guide/rhai) functions for [Neblex Integration Fabric](https://www.neblex.com/integration-fabric) flows. A module is a set of plain functions that a Code step imports by name. Rhai runs in a sandbox with no file, network or system access, so a module can only transform the values it's given.

| Module | What it does |
|---|---|
| [data-quality](data-quality/data-quality.rhai) | Cleans and checks contact and company records: emails, phone numbers, names, company names, domains, US ZIP codes and states, and missing fields |
| [dates](dates/dates.rhai) | Reads dates written in common formats into YYYY-MM-DD, converts Excel serial dates and counts days between dates |
| [numbers](numbers/numbers.rhai) | Reads numbers and amounts written in US or European formats, percentages and currency codes |

Each module stands alone, and a Code step can import several of them at once.

For jobs that are awkward in a script, such as parsing emails, XML, PDFs or fixed-width files, use a compiled module from [neblex-wasm-modules](https://github.com/neblexhq/neblex-wasm-modules) instead.

## data-quality

Use it to clean records before they reach a CRM, ERP or warehouse, and to build match keys for finding duplicates.

### Functions

| Function | Returns | Example |
|---|---|---|
| `is_blank(v)` | true when missing, empty or only spaces | `is_blank("  ")` → `true` |
| `clean_text(v)` | text trimmed, runs of whitespace collapsed | `"  Acme \t Corp "` → `"Acme Corp"` |
| `digits_only(v)` | only the digits 0-9 | `"(415) 555-0123"` → `"4155550123"` |
| `normalize_email(v)` | trimmed, lowercased, `mailto:` and `<>` removed | `" Jane.Doe@Example.COM "` → `"jane.doe@example.com"` |
| `is_valid_email(v)` | true when the address is well formed (it doesn't check the mailbox exists) | `"jane@example"` → `false` |
| `email_domain(v)` | the domain after the @ | `"Jane@Acme.com"` → `"acme.com"` |
| `is_free_email(v)` | true for common free mail providers | `"someone@gmail.com"` → `true` |
| `is_role_email(v)` | true for shared addresses such as info@ or sales@ | `"sales+eu@acme.com"` → `true` |
| `email_match_key(v)` | a key for finding duplicate people: `+tag` removed, Gmail dots ignored | `"J.Doe+news@googlemail.com"` → `"jdoe@gmail.com"` |
| `phone_e164(v, default_cc)` | the number in E.164 format, or `""` when it can't be valid; `default_cc` is the calling code for numbers without `+` or `00` | `phone_e164("(415) 555-0123 x45", "1")` → `"+14155550123"` |
| `title_case_name(v)` | a person's name with each part capitalized | `"o'NEIL"` → `"O'Neil"`, `"MCDONALD"` → `"McDonald"` |
| `split_full_name(v)` | `first_name` and `last_name`; handles "Last, First" | `"Smith, John"` → `#{first_name: "John", last_name: "Smith"}` |
| `company_match_key(v)` | a key for matching company names: punctuation, "the" and legal forms removed | `"The Acme Company, Inc."` and `"ACME Co"` → `"acme"` |
| `domain_from_url(v)` | the host from a website or email address | `"https://www.Acme.com/about"` → `"acme.com"` |
| `us_zip(v)` | `12345` or `12345-6789`, restoring a leading zero a spreadsheet dropped | `"2134"` → `"02134"` |
| `us_state_code(v)` | the two-letter code for a US state, DC or Puerto Rico | `"N.Y."` → `"NY"` |
| `missing_fields(record, fields)` | the listed fields that are missing or blank | `["company", "phone"]` |
| `completeness(record, fields)` | share of the listed fields that are filled in, 0.0 to 1.0 | `0.67` |

Each function returns a value and changes nothing else, so you can combine them in any order. Invalid input returns an empty or false result instead of stopping the flow, so you can route those records to review.

### Use it in a flow

1. In Neblex, add a Transform Module named `data-quality` and paste in [data-quality.rhai](data-quality/data-quality.rhai). The other modules work the same way, named `dates` and `numbers`. From an AI client connected to the [Neblex MCP server](https://github.com/neblexhq/neblex-mcp), you can ask it to create the module from this file instead.
2. Add a Code step, set it to **Each record**, and add `data-quality` under **Imported modules**.
3. Call the functions in the step's script:

```rhai
item.email = normalize_email(item.email);
item.email_valid = is_valid_email(item.email);
item.phone = phone_e164(item.phone, "1");
item.first_name = title_case_name(item.first_name);
item.last_name = title_case_name(item.last_name);
item.company_key = company_match_key(item.company);
item.domain = if is_free_email(item.email) { domain_from_url(item.website) } else { email_domain(item.email) };
item.missing = missing_fields(item, ["email", "phone", "company"]);
```

With these two leads as input:

```json
{ "first_name": "DANA", "last_name": "o'reilly", "email": " Dana.OReilly@Northwind.com ", "phone": "(415) 555-0123", "company": "Northwind Traders, Inc.", "website": "https://www.northwind.com" }
{ "first_name": "sam", "last_name": "okafor", "email": "sam.okafor@gmail.com", "phone": "555-0199", "company": "", "website": "contoso.com/about" }
```

the step returns:

```json
{ "first_name": "Dana", "last_name": "O'Reilly", "email": "dana.oreilly@northwind.com", "email_valid": true, "phone": "+14155550123", "company_key": "northwind traders", "domain": "northwind.com", "missing": [] }
{ "first_name": "Sam", "last_name": "Okafor", "email": "sam.okafor@gmail.com", "email_valid": true, "phone": "", "company_key": "", "domain": "contoso.com", "missing": ["phone", "company"] }
```

(The original `company` and `website` fields are kept too; they're left out above for space.) Sam's number has no area code, so it can't be turned into a valid phone number and comes back empty. Sam's email is a free address, so the company domain comes from the website.

From there, a filter on `email_valid` or `missing` can send incomplete records to a person for review, and a Deduplicate step can match on `company_key` or `email_match_key`.

### Limits

- `is_valid_email` checks the format only, and rejects international (non-ASCII) addresses.
- `phone_e164` checks length and, for +1 numbers, the area code and exchange. It doesn't know every country's numbering plan.
- `title_case_name` capitalizes every part, including particles such as "van" or "de".
- `split_full_name` puts everything after the first word into `last_name`.
- Rhai in Neblex has no regular expressions, so the checks are written character by character.

## dates

Use it when dates arrive as text in mixed formats, from spreadsheets, CSV exports, forms or older systems, and need to be one format before they're loaded.

| Function | Returns | Example |
|---|---|---|
| `to_iso_date(v, order)` | the date as YYYY-MM-DD, or `""` when it can't be read or isn't a real date; `order` is `"mdy"` or `"dmy"` for all-number dates | `to_iso_date("04/03/2026", "mdy")` → `"2026-04-03"`, with `"dmy"` → `"2026-03-04"` |
| `excel_serial_to_iso(v)` | the date for an Excel serial number (Excel's default 1900 date system); a time fraction is ignored | `45750` → `"2025-04-03"` |
| `is_valid_iso_date(v)` | true when the value is exactly YYYY-MM-DD and a real date | `"2026-02-30"` → `false` |
| `days_between(a, b)` | whole days from date `a` to date `b`, both YYYY-MM-DD | `days_between("2026-04-03", "2026-04-01")` → `-2` |
| `is_leap_year(y)` | true for leap years | `2024` → `true`, `1900` → `false` |
| `days_in_month(y, m)` | days in that month | `days_in_month(2024, 2)` → `29` |

`to_iso_date` reads, for example, `2026-04-03`, `2026/4/3`, `20260403`, `04/03/2026`, `4/3/26`, `03.04.2026`, `3 Apr 2026`, `April 3rd, 2026`, `Fri, 3-Apr-26` and `2026-04-03T10:20:00Z`. Dates that start with a four-digit year are always read as year, month, day, and a time after the date is ignored.

```rhai
item.order_date = to_iso_date(item.order_date, "mdy");
item.invoice_date = excel_serial_to_iso(item.invoice_date);
item.days_open = days_between(item.order_date, item.invoice_date);
```

Limits:

- An all-number date such as `04/03/2026` can't be read without knowing the source's convention, so `order` is required for those; with any other value they return `""`.
- Two-digit years 00 to 69 become 2000 to 2069; 70 to 99 become 1970 to 1999.
- Month names are English only. Time zones are not converted; the date is taken as written.

## numbers

Use it when amounts arrive as text: exports with thousands separators, European decimal commas, currency symbols, or negatives written as `(500)` or `500-`.

| Function | Returns | Example |
|---|---|---|
| `parse_number(v, decimal_sep)` | the number, or `()` when none can be read; `decimal_sep` is `"."`, `","` or `"auto"` | `"1.234,56"` → `1234.56`, `"(500)"` → `-500.0`, `"1,234-"` → `-1234.0` |
| `parse_percent(v, decimal_sep)` | a percentage as a fraction | `"12.5%"` → `0.125` |
| `to_cents(v, decimal_sep)` | the amount in whole cents | `"$1,234.56"` → `123456` |
| `currency_code(v, dollar_default)` | the ISO 4217 code from a code or symbol; a plain `$` returns `dollar_default` | `"EUR 1.234,56"` → `"EUR"`, `"R$ 50"` → `"BRL"` |

```rhai
item.currency = currency_code(item.amount_text, "USD");
item.amount = parse_number(item.amount_text, "auto");
item.amount_cents = to_cents(item.amount_text, "auto");
item.discount = parse_percent(item.discount_text, "auto");
```

Limits:

- With `"auto"`, a single separator followed by exactly three digits (`1,234` or `1.234`) is read as a thousands separator. If a source uses a comma for decimals with three decimal places, pass `","` instead.
- Currency symbols, codes and units around the number are ignored; letters inside it (`12a34`) make it unreadable.
- `to_cents` assumes two decimal places, so it doesn't fit currencies such as JPY that have none.

## Tests

Each module has a `test` folder with `cases.json` (test cases, each with an input and the expected result) and `harness-script.rhai`, the Code step that runs them. To run them, build a flow with a Webhook trigger, an Unwind step on `cases`, and the harness script in a Code step set to Each record with the module imported. Send `cases.json` as the payload and every output record should have `pass: true`.

| Module | Test cases | Result in our test |
|---|---|---|
| data-quality | [88](data-quality/test/cases.json) | all passed |
| dates | [43](dates/test/cases.json) | all passed |
| numbers | [36](numbers/test/cases.json) | all passed |

The dates and numbers tests ran in one Code step with all three modules imported together.

The same cases also run automatically on every change with the [Rhai](https://rhai.rs) engine (`test-runner/`), each module on its own and all three loaded together. To run them yourself from the repository root, with Rust installed:

```sh
cargo run --release --manifest-path test-runner/Cargo.toml
```

Neblex runs Rhai in its own sandbox, so the result in a Neblex flow is the one that counts; the automated run catches mistakes before a change reaches it.

## Links

- [Scripting with Rhai in Neblex](https://www.neblex.com/integration-fabric/docs/guide/rhai)
- [Neblex Integration Fabric](https://www.neblex.com/integration-fabric)
- [WebAssembly modules for Neblex](https://github.com/neblexhq/neblex-wasm-modules)
- [Neblex MCP server](https://github.com/neblexhq/neblex-mcp)

## License

MIT. See [LICENSE](LICENSE).
