# Async image loader / cache (senior iOS live task)

Built from `01-minimal`. Sources: a senior iOS loop whose coding round was "implement an async image loader" (search summary), salari.dev's list of the five common live tasks (task 3: an image cache for list thumbnails with no duplicate downloads, [link](https://salari.dev/writing/ios-coding-interview-questions/)), and an Apple phone screen on an "image manager" ([LeetCode](https://leetcode.com/discuss/interview-question/501476/), summary only). Aim for 45–60 minutes.

## What is built
- `ImagePipeline` (actor): memory cache → in-flight task → download → downsample → cache.
- `Downsampler`: ImageIO thumbnail decode at display size (EXIF orientation respected).
- `LRUCache`: deterministic count limit (testable); mention NSCache for OS-driven purging.
- `CachedImage` (SwiftUI): `.task(id: url)`, resets the image first so a reused row never shows the previous picture.
- Demo: a 300-cell grid over 60 URLs (5 cells per URL, one download each).

## The points they grade (in order)
| # | Point | How it's handled | Test |
|---|---|---|---|
| 1 | Thread safety | `actor` owns both caches | — |
| 2 | **Actor reentrancy** | An actor is not locked across `await`: two calls can both miss the cache. The in-flight `Task` is stored and shared | 10 concurrent requests → 1 download |
| 3 | Memory hit | LRU checked first | second call → no download |
| 4 | **Failures not cached** | In-flight entry removed on error | fail then success → 2 downloads |
| 5 | **Cancellation semantics** | Each caller is a waiter; one leaving does not cancel the shared download; the **last** one leaving cancels it (`withTaskCancellationHandler`) | both cases tested |
| 6 | Memory | Decode at `pointSize × displayScale`; LRU count limit | 1000×500 → 100×50; LRU keeps 2 of 3 |
| 7 | Stale cell image | `.task(id: url)` cancels the old load; image reset before loading | — |

## Follow-ups to be ready for
- **Disk cache:** `URLCache` with a larger disk capacity for HTTP caching, or files keyed by a URL hash with an LRU size cap; check memory → disk → network.
- **Priorities / prefetching:** `UICollectionViewDataSourcePrefetching` or `.onAppear` prefetch with lower `TaskPriority`; cancel prefetches that scroll away.
- **Memory warnings:** clear the memory cache on `didReceiveMemoryWarningNotification` (NSCache does this for you).
- **Why not `AsyncImage`?** No caching beyond `URLCache`, no downsampling, no control over dedupe or cancellation.

## Tests (12)
Pipeline (7) + core (5). Run `swift test`; repeated 5× locally without flakes.
