// Code step script used by the test flow (Each record mode, module "dates" imported).
// Each test case record has: func, input, arg (optional), expected.
let got = switch item.func {
  "to_iso_date" => to_iso_date(item.input, item.arg),
  "is_valid_iso_date" => is_valid_iso_date(item.input),
  "excel_serial_to_iso" => excel_serial_to_iso(item.input),
  "days_between" => days_between(item.input, item.arg),
  "is_leap_year" => is_leap_year(item.input),
  "days_in_month" => days_in_month(item.input, item.arg),
  "add_days_iso" => add_days_iso(item.input, item.arg),
  "day_of_week" => day_of_week(item.input),
  "add_business_days" => add_business_days(item.input, item.arg),
  "iso_week" => iso_week(item.input),
  "end_of_month" => end_of_month(item.input),
  "unix_to_iso" => unix_to_iso(item.input),
  "quarter" => quarter(item.input),
  "fiscal_year" => fiscal_year(item.input, item.arg),
  "fiscal_quarter" => fiscal_quarter(item.input, item.arg),
  "business_days_between" => business_days_between(item.input, item.arg),
  _ => "unknown function"
};
#{ func: item.func, input: item.input, expected: item.expected, got: got, pass: got == item.expected }
