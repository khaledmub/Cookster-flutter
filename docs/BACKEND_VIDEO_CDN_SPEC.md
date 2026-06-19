# Backend video CDN contract (mobile integration)

Backend returns a consistent video payload on reels, profile, hashtag/list feeds, saved/liked, single video, and upload poll. **Use these fields only — do not build URLs from filenames.**

## Required fields per video

| Field | Use |
|-------|-----|
| `transcode_status` | `"ready"` = HLS + MP4 ladder available |
| `processing_status` | `"processing"` = show poster only; don't guess HLS |
| `hls_playlist_url` or `hls_url` | Primary playback (master `.m3u8`) |
| `video_sources.url_360` | Fast-start MP4 fallback |
| `video_sources.url_720` / `url_1080` | Higher quality fallbacks |
| `video_url` | Legacy full MP4 |
| `thumbnail_url` / `thumbnail` | Poster while buffering |
| `thumbnail_blur` | Tiny blur placeholder |
| `image_url` / `image` | Cover/fallback while processing |
| `id` | Player pool + preload key |

## Playback priority (when `transcode_status == "ready"`)

`hls_playlist_url` → `url_360` → `url_720` → `url_1080` → `video_url` → `video`

When **not** ready: use `thumbnail_url` / `image_url` as poster; only fall back to `video_url` / `video` if you must (slow).

## After upload

- `POST /api/videos/create` returns `video_id` + decorated video immediately (`transcode_status: pending`, `processing_status: processing`).
- Poll `GET /api/videos/processing_status?video_id={id}` until both are `"ready"`, or refresh profile/reels.
- Poll response includes full media fields: `hls_playlist_url`, `video_sources`, `thumbnail_url`, etc. — same shape as feed items.

## Profile avatars

- Use `image_url` / `user.image` from API as **absolute URLs** — do not prepend `media_base_url`.
- Correct CDN path: `https://cdn.cookster.org/storage/front_users/{filename}.jpg`
- Don't fix 404s client-side by swapping `/storage/front_users/` vs `/front_users/` — backend normalizes; if 404, show default avatar.

## Encoding requirements (smooth playback)

For Instagram/Snapchat-level reel smoothness, encode all ladder MP4s with:

| Requirement | Target |
|-------------|--------|
| Fast-start layout | `moov` atom **before** `mdat` in 360.mp4 and 720.mp4 |
| GOP / keyframe interval | 1–2 seconds |
| CDN `Cache-Control` | `public, max-age=31536000, immutable` on versioned paths |
| Range requests | Enabled on all MP4 and HLS segment responses |
| `thumbnail_blur` | Required on every `transcode_status=ready` item |

Mobile uses partial-cache playback when ≥256 KiB are on disk and `moov` is at the front.

## Preload behavior (mobile)

- Preload next 2–4 reels when `transcode_status == "ready"` and URLs are non-null.
- Keep poster visible until first frame.
- Respect Remote Config (`reels_preload_enabled`, data saver).

## What not to do

- Don't mark a reel playable from HLS until `transcode_status == "ready"`.
- Don't construct CDN paths from raw DB filenames.
- Don't double-prefix URLs with `media_base_url` when value already starts with `https://`.

## Example ready item

```json
{
  "id": "uuid",
  "transcode_status": "ready",
  "processing_status": "ready",
  "hls_playlist_url": "https://cdn.cookster.org/videos/{id}/hls/master.m3u8",
  "video_sources": {
    "url_360": "https://cdn.cookster.org/videos/{id}/360.mp4",
    "url_720": "https://cdn.cookster.org/videos/{id}/720.mp4",
    "url_1080": "https://cdn.cookster.org/videos/{id}/1080.mp4"
  },
  "thumbnail_url": "https://cdn.cookster.org/videos/{id}/thumb.webp",
  "thumbnail_blur": "https://cdn.cookster.org/videos/{id}/thumb_blur.webp"
}
```

## Endpoints with same video shape

- `GET /api/reels`
- Profile videos (`GET /api/profile`, `GET /api/profile_details`)
- `POST /api/videos/list` (incl. hashtag via tags)
- `POST /api/videos/saved_list`, `liked_videos_list`
- `GET /api/videos/details`
- `GET /api/videos/processing_status`

## Mobile one-liner

Use absolute CDN URLs from the API; play HLS when `transcode_status=ready`, else poster + MP4 fallback; poll `processing_status` after upload; never build video/avatar URLs yourself.
