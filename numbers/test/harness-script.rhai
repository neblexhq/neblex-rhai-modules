// Code step script used by the test flow (Each record mode, module "numbers" imported).
// Each test case record has: func, input, arg, arg2 (optional), expected.
let got = switch item.func {
  "parse_number" => parse_number(item.input, item.arg),
  "parse_percent" => parse_percent(item.input, item.arg),
  "to_cents" => to_cents(item.input, item.arg),
  "currency_code" => currency_code(item.input, item.arg),
  "round_half_even" => round_half_even(item.input, item.arg),
  "format_number" => format_number(item.input, item.arg, item.arg2),
  "percent_change" => percent_change(item.input, item.arg),
  "safe_divide" => safe_divide(item.input, item.arg, item.arg2),
  "parse_duration" => parse_duration(item.input, item.arg),
  _ => "unknown function"
};
#{ func: item.func, input: item.input, expected: item.expected, got: got, pass: got == item.expected }
