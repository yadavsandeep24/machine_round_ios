# Fintech: transaction history (Swift)

Built from `01-minimal`. A **domain problem**: the core list screen of every payments/banking app (and lesson 11 of your Flutter prep). Aim for 60–90 minutes.

## What is built
- `List` with `Section`s per **local** day ("Today", "Yesterday", "3 Nov", "31 Dec 2025") and a per-day net of successful transactions.
- Segmented Received / Paid filter, status menu (Pending / Failed), `.searchable` with a debounced server query.
- Cursor pagination with footer spinner / Retry, pull-to-refresh, signed INR amounts (`+₹1,250.00`), failed amounts struck through, one VoiceOver label per row.

## How the concurrency works
```
.task(id: model.searchText) { debounceSearch() }   cancellable sleep → query
.task(id: model.filter)     { reload() }            filter = kind + status + query
                                                     a change cancels the old load; checkCancellation drops its result
footer .task { loadMore() }                          guarded; ignored if the filter changed meanwhile
```

## Points to make in the round
| Topic | Answer |
|---|---|
| Cursor vs page number | New transactions arrive at the top; offsets then repeat/skip rows. Dedupe by id anyway. |
| Timezones | Server sends UTC; group with `Calendar.current.startOfDay` (tests pin Asia/Kolkata). |
| Money | `Int64` minor units → `Decimal` → `.currency(code: "INR").locale(en_IN)` for lakh grouping. |
| Derived data | `sections` is computed per body evaluation: fine for hundreds of rows; cache it on `items` changes for thousands. |
| Real time | Push/WebSocket inserts at the top with dedupe; keep scroll position. |
| Offline | Cache page 1 (SwiftData/SQLite/file) for an instant start with "Updated …". |
| Privacy | Mask account numbers/VPAs; honour "hide balances"; blur the app-switcher snapshot. |

## Tests (12)
Grouping (3): day titles in order, net of successes only, signed INR. View model (4): cursor pages to the end, filter change cancels the old load, debounced search becomes the server query, first-page error + retry. Plus core (5).
