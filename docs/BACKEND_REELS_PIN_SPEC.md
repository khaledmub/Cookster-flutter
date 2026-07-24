# Reels feed pin contract (client integration)

Canonical server behavior is implemented in the backend (`ReelsController`, upload
`feed_hint` in `ApiController`). The Flutter app **must not** reorder feed rows
locally for uploads — it sends `pin_video_id` once and the server pins when rules match.

## Upload response

After a successful upload:

```json
{
  "video_id": "...",
  "feed_hint": {
    "reels_query": {
      "country": 194,
      "city": 102874,
      "sort_by": "newest",
      "pin_video_id": "..."
    },
    "pin_expires_at": "2026-07-25T20:00:00+00:00"
  }
}
```

Client: `ReelsFeedPinStore.saveFromUploadResponse()` persists `feed_hint`.

## First feed fetch after upload

```
GET /api/reels?country=194&city=102874&sort_by=newest&pin_video_id={video_id}
Authorization: Bearer {token}
```

Near Me (when applicable):

```
GET /api/reels?feed=near_me&latitude=...&longitude=...&sort_by=newest&pin_video_id={video_id}
```

## Pin rules (server-enforced)

| Rule | Detail |
|------|--------|
| Scope | `general` and `near_me` only |
| Auth | Required — guests ignore `pin_video_id` |
| Ownership | Must be viewer's own upload |
| Recency | ≤ 24 hours old |
| Geo | Must match active country/city filter |
| Pagination | First page only; cursor carries `consumed_pin_id` |

Response may include `meta.pinned_video_id` when pin is applied.

## Client behavior

1. Parse and store `feed_hint` on upload success.
2. On **first page** reels fetch (`reset=true`), append `pin_video_id` when stored hint matches the active tab + filter + sort.
3. Do **not** send `pin_video_id` on pagination (`cursor` requests).
4. Clear stored pin after the first pinned fetch attempt (single use).
5. Do not prepend or re-sort feed items locally.

## What pin is not for

Older uploads (e.g. created months ago) are correctly ranked by `sort_by=newest`
and will not pin — that is intentional.
