// Code step script used by the test flow (Each record mode, module "data-quality" imported).
// Each test case record has: func, input, arg (optional), expected.
let got = switch item.func {
  "is_blank" => is_blank(item.input),
  "clean_text" => clean_text(item.input),
  "digits_only" => digits_only(item.input),
  "normalize_email" => normalize_email(item.input),
  "is_valid_email" => is_valid_email(item.input),
  "email_domain" => email_domain(item.input),
  "is_free_email" => is_free_email(item.input),
  "is_role_email" => is_role_email(item.input),
  "email_match_key" => email_match_key(item.input),
  "phone_e164" => phone_e164(item.input, item.arg),
  "title_case_name" => title_case_name(item.input),
  "split_full_name" => split_full_name(item.input),
  "company_match_key" => company_match_key(item.input),
  "domain_from_url" => domain_from_url(item.input),
  "us_zip" => us_zip(item.input),
  "us_state_code" => us_state_code(item.input),
  "missing_fields" => missing_fields(item.input, item.arg),
  "completeness" => completeness(item.input, item.arg),
  "country_code" => country_code(item.input),
  "is_valid_url" => is_valid_url(item.input),
  "luhn_valid" => luhn_valid(item.input),
  _ => "unknown function"
};
#{ func: item.func, input: item.input, expected: item.expected, got: got, pass: got == item.expected }
