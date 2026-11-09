// Code step script used by the test flow (Each record mode, module "text" imported).
// Each test case record has: func, input, arg (optional), arg2 (optional), expected.
let got = switch item.func {
  "remove_accents" => remove_accents(item.input),
  "slugify" => slugify(item.input),
  "truncate_words" => truncate_words(item.input, item.arg),
  "initials" => initials(item.input),
  "mask_middle" => mask_middle(item.input, item.arg, item.arg2),
  "pad_left" => pad_left(item.input, item.arg, item.arg2),
  "strip_html" => strip_html(item.input),
  "word_count" => word_count(item.input),
  "title_case" => title_case(item.input),
  "snake_case" => snake_case(item.input),
  "camel_case" => camel_case(item.input),
  "split_words" => split_words(item.input),
  "kebab_case" => kebab_case(item.input),
  "extract_hashtags_mentions" => extract_hashtags_mentions(item.input),
  "normalize_quotes" => normalize_quotes(item.input),
  _ => "unknown function"
};
#{ func: item.func, input: item.input, expected: item.expected, got: got, pass: got == item.expected }
