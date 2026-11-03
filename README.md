# Neblex Rhai modules

Reusable [Rhai](https://www.neblex.com/integration-fabric/docs/guide/rhai) functions for [Neblex Integration Fabric](https://www.neblex.com/integration-fabric) flows. A module is a set of plain functions that a Code step imports by name. Rhai runs in a sandbox with no file, network or system access, so a module can only transform the values it's given.

| Module | What it does |
|---|---|
| [data-quality](data-quality/data-quality.rhai) | Cleans and checks contact and company records: emails, phone numbers, names, company names, domains, US ZIP codes and states, and missing fields |

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

1. In Neblex, add a Transform Module named `data-quality` and paste in [data-quality.rhai](data-quality/data-quality.rhai). From an AI client connected to the [Neblex MCP server](https://github.com/neblexhq/neblex-mcp), you can ask it to create the module from this file instead.
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

## Tests

[data-quality/test/cases.json](data-quality/test/cases.json) has 76 test cases, each with an input and the expected result. [harness-script.rhai](data-quality/test/harness-script.rhai) is the Code step that runs them: a flow with a Webhook trigger, an Unwind step on `cases`, and this Code step (Each record, `data-quality` imported). Send `cases.json` as the payload and every output record should have `pass: true`. All 76 passed in our test.

## Links

- [Scripting with Rhai in Neblex](https://www.neblex.com/integration-fabric/docs/guide/rhai)
- [Neblex Integration Fabric](https://www.neblex.com/integration-fabric)
- [Neblex MCP server](https://github.com/neblexhq/neblex-mcp)

## License

MIT. See [LICENSE](LICENSE).
