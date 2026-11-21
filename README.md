# JSON decoding: snake_case, dates, optionals, malformed items

Built from `01-minimal`. Source: salari.dev's list of the five common iOS live tasks (task 2, [link](https://salari.dev/writing/ios-coding-interview-questions/)): decode a payload with a snake_case key, a date string and an optional field; graded on matching optionality to the real data, using key/date strategies on purpose, and **saying what one bad item does to the whole array**. Usually 15–25 minutes, often the warm-up before a list screen.

## What the sample payload throws at you (`SampleOrders.json`)
| Trap | Handling |
|---|---|
| `created_at`, `items_count` | `keyDecodingStrategy = .convertFromSnakeCase` |
| `order_id` → `id` | one explicit `CodingKeys` case (written as `orderId`, because the snake_case conversion happens first) |
| Dates with and without fractional seconds | custom `dateDecodingStrategy` trying both ISO 8601 styles |
| Money as a string `"1250.50"` | `Decimal(string:)` with a POSIX locale; never `Double` (tested: exact sum) |
| `coupon_code: null` vs missing | `decodeIfPresent` → `nil` either way |
| `items_count` missing in old data | `decodeIfPresent ?? 0`, a deliberate default |
| `status: "refunded_partial"` (new on the server) | `.unknown(raw)` instead of a crash for old app versions |
| One order without `order_id` | `@Lossy` array: skip it, log why, keep the rest |

## The decision to say out loud
**Lossy vs strict.** For a display list, one bad row should not blank the screen: skip and log it so the backend gets fixed (`page.$items.skipped`). For data where a missing element is dangerous (payment line items, balances, ledger entries), fail the whole decode and show an error.

## Also mention
- Reuse one configured `JSONDecoder` (formatters are expensive to create).
- Decode off the main actor for big payloads.
- `Codable` synthesis vs a manual `init(from:)`: write it by hand only for the fields that need it.

## Tests (12)
Snake case + renamed key, malformed item skipped not fatal, fractional-second dates, exact `Decimal` money, null vs missing vs default, unknown status, bad date fails only that item. Plus core (5).
