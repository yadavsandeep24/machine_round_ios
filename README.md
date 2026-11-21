# Swiggy: weather list with favourites synced across screens

Built from `01-minimal`. Source: a Swiggy iOS interview ([Medium](https://medium.com/@pranav_ps/swiggy-ios-interview-experience-ad1018f12353), about 2023, search summary only). Round 1 was a **1.5-hour machine coding** task: a weather app with a **sorted city list** and a **favourite button that stays in sync across two screens**. The candidate took 70 minutes and did not finish the favourite logic. Follow-ups: why `self` in the closure, and `weak` vs `unowned`. API: [Open-Meteo](https://open-meteo.com) (free, no key).

## What is built
- Cities tab: 10 Indian cities, current temperature and condition, sort by name / warmest / coldest, pull-to-refresh.
- Favourites tab (with a badge count) and a detail screen; the ☆ works from all three and is persisted.
- **One request for all cities** (Open-Meteo takes comma-separated coordinates; one location returns an object, several return an array, both handled).

## The point of the task: one source of truth
`WeatherStore` (`@MainActor @Observable`) is created once and injected with `.environment(store)`. The list, the favourites tab and the detail screen all **read** `favouriteIds` from it and call `toggleFavourite`; nobody keeps a copy. That is why the button can't get out of sync. The usual bug is each screen holding its own array of favourites (or a value-type copy of the city) and forgetting to propagate the change back.

## Follow-up: `self` in closures, `weak` vs `unowned`
`ClosureCaptureExample.swift` and its test:
- A class that **stores** a closure capturing `self` strongly forms a cycle (controller → scheduler → closure → controller) and is never freed (tested: still alive after scope).
- `[weak self]`: the closure doesn't own the controller; `self?` becomes nil safely (tested: freed).
- `[unowned self]`: no optional, but crashes if the closure outlives `self`; only when lifetimes are guaranteed (for example, a child that cannot outlive its parent).
- SwiftUI `.task {}` and non-escaping closures (`map`, `forEach`) don't need `weak`; a stored `Task { }` that loops forever does (or cancel it in `deinit`).

## Tests (11)
Store (3): sorting by name/warm/cold, favourite visible everywhere + persisted, failure then retry. Service (2): array and single-object responses. Closures (1): strong capture leaks, weak capture doesn't. Plus core (5).

## Extend it (likely follow-ups)
Search cities (`.searchable`), hourly forecast on the detail screen, offline cache of the last response with "Updated 10 min ago", unit toggle °C/°F stored in `@AppStorage`.
