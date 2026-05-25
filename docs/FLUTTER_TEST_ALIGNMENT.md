# Flutter test API alignment

Test/staging API: **https://cookster.mubreq.com/api/**

Production (after QA): **https://cookster.org/api/**

## Build / run

Default base URL in this branch points at the **test** host. Override at build time:

```bash
# Test (default in lib/appUtils/apiEndPoints.dart)
flutter run

# Production
flutter run --dart-define=API_BASE_URL=https://cookster.org/api/

# Custom staging
flutter run --dart-define=API_BASE_URL=https://cookster.mubreq.com/api/
```

Auth is unchanged: `Authorization: Bearer <sanctum_token>`.

## Paginated feeds

| Screen | Method | Endpoint | Pagination |
|--------|--------|----------|------------|
| Home / hashtag | POST | `videos/list` | `paginate=1`, `per_page=15`, `page=1` on refresh; load more via `meta.next_cursor` (or cursor fields in `FeedMeta.toRequestPayload()`) |
| Search (types 1–4) | POST | `search` | `paginate=1`, `per_page=30`, `page++` while `meta.has_more` |
| Saved | POST | `videos/saved_list` | same page pattern |
| Liked | POST | `videos/liked_videos_list` | same + `video_ids` |
| Public list | GET | `videos/list2` | page + `meta.has_more` (not wired in app yet) |

**Never** omit `paginate=1` on the home feed — that uses the legacy full-list path.

Stop infinite scroll when `meta.has_more == false`.

## Media URLs

API returns absolute CDN URLs on `video_url`, `thumbnail_url`, `image_url`, `user_image` / `user_image_url`. The client uses `MediaUrlResolver` and `WallVideos` extensions — **do not** prepend `Common.videoUrl` or `Common.profileImage` when the value already starts with `https://`.

### Reels playback (`transcode_status: ready`)

1. `hls_playlist_url` / `hls_url` (e.g. `…/videos/{id}/hls/master.m3u8`)
2. `video_sources.url_360` → `url_720` → `url_1080`
3. `video_url` full-res fallback only if ladder/HLS unavailable

When `transcode_status` is not `ready`, playback uses `video_url` only (HLS / `video_sources` are null until the transcode queue finishes).

### Posters (`processing_status`)

- `processing_status: ready` → use API `thumbnail_url` as-is (CDN `…/thumb.webp`; file must exist on CDN after backfill).
- `processing_status: pending` → prefer `image` / `image_url`; still use API `thumbnail_url` if no cover (legacy path).
- On poster 404, `resolvedReelPosterFallbackUrl` shows grid/cover.
- Do not synthesize `thumb.webp` paths in the app.

### Avatars

`MediaUrlResolver.profileImageUrl(value)` — absolute CDN as-is, else prefix `Common.profileImage`.

| Endpoint | Avatar field |
|----------|----------------|
| GET `/api/reels` | `user.image` (nested; no top-level `user_image_url`) |
| Feeds / profile lists | `user_image` or `user_image_url` |

Parser prefers nested `user.image` on reels, then feed-level fields.

Legacy relative filenames still resolve against `Common.videoUrl` (GCS).

## Upload + thumbnail processing

1. `POST videos/create` — UI returns immediately on 200/201.
2. Background poll: `GET videos/processing_status?video_id={uuid}` every ~2s until `ready` or `failed` (`VideoProcessingService`).
3. Show local/generated thumbnail until server `thumbnail_url` is ready.

Queue worker must be running on the server for thumbnails to flip to `ready`.

## Sanity curl (before app QA)

```bash
curl -s -X POST 'https://cookster.mubreq.com/api/videos/list' \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -d '{"paginate":1,"per_page":15,"page":1,"latitude":"24.7","longitude":"46.7"}' \
  | jq '.meta, (.videos[0] | {video_url, thumbnail_url, processing_status})'
```

Expect `meta.has_more`, `meta.feed_seed`, `meta.next_cursor`, and `https://` URLs on video fields.

## QA checklist

| # | Test | Pass |
|---|------|------|
| 1 | Cold open home feed — ~15 videos, &lt; ~1–2s on WiFi | |
| 2 | Scroll 20+ reels — no multi-second freezes; load more before end | |
| 3 | Pull to refresh — new `feed_seed` / page 1 reset | |
| 4 | Saved list — first page + scroll load more | |
| 5 | Liked list — same | |
| 6 | Search videos — paginated, no timeout | |
| 7 | Profile (self + other) — videos grouped by type | |
| 8 | Notifications — list loads | |
| 9 | Upload video + image — fast API; thumbnail after poll | |
| 10 | Play reel — no double CDN path in URL | |
| 11 | Upload without waiting — app usable while `processing` | |

## Client performance notes

- Feed JSON parsed in a background isolate (`compute` + `video_feed_parser.dart`).
- Reels: player pool + preload next item; show `thumbnail_url` before full buffer.
- Infinite scroll: `PaginatedScrollMixin` on saved / liked / search grids.
