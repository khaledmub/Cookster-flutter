# Backend video CDN contract (mobile integration)

Backend returns a consistent video payload on reels, profile, hashtag/list feeds, saved/liked, single video, and upload poll. **Use these fields only — do not build URLs from filenames.**

## Required fields per video

| Field | Use |
|-------|-----|
| `transcode_status` | `"ready"` = HLS + MP4 ladder available |
| `processing_status` | `"processing"` = show poster only; don't guess HLS |
| `playback_ready` | Optional explicit gate; prefer over inferring from status alone |
| `hls_playlist_url` or `hls_url` | Adaptive playback (master `.m3u8`, ~2s segments) |
| `video_sources.url_360` | Fast-start MP4 (always present when ready) |
| `video_sources.url_720` | Default sharp MP4 — **required before ready** |
| `video_sources.url_1080` | When source ≥ ~918p; optional |
| `video_url` | Legacy full MP4 (avoid when ladder exists) |
| `thumbnail_url` / `thumbnail` | Sharp frame poster (`thumb.webp`, ~720 long-edge) |
| `thumbnail_blur` | Tiny blur placeholder |
| `image_url` / `image` | Cover/fallback while processing |
| `id` | Player pool + preload key |

## Playback priority (client — when `transcode_status == "ready"`)

**MP4 ladder (current app default):** ready cache → **720** → 1080 → 360 → `video_url`.  
Wi‑Fi opens 720 (or ready 1080); cellular opens 360 then upgrades to cached 720.

**HLS (Remote Config `reels_hls_wifi_enabled`):** master playlist first on Wi‑Fi when enabled; MP4 remains fallback. Segments are ~2s — no extra backend pass needed to flip the flag.

When **not** ready: poster only (`thumbnail_url` / `image_url`); do not invent ladder URLs.

## Encoding guarantees (transcoder — Jul 2026)

| Requirement | Implementation |
|-------------|----------------|
| Fast-start | `-movflags +faststart` on every ladder MP4 (`moov` before `mdat`) |
| Even dimensions | Shared filter `scale=-2:H:flags=lanczos,setsar=1,format=yuv420p` + `-pix_fmt yuv420p` (MP4 + HLS). Avoids odd axes (e.g. 721) that stall Honor/MediaTek surfaces |
| Ladder completeness | Always encode **360 + 720** when ready (mild upscale OK). **1080** when source ≥ ~918p. Verifier **requires `url_720` before ready** |
| CDN cache | Ladder MP4s + posters: `Cache-Control: public, max-age=31536000, immutable`. HLS playlists: `max-age=60`. Range requests enabled |
| Sharp poster | Transcode overwrites `thumb.webp` from a real frame (~720 long-edge, q88, even dims) |

Mobile partial-cache playback needs ≥256 KiB on disk **and** moov-at-front — both are now guaranteed on new encodes; backfill remuxes older files.

## Backfill (existing catalog)

```bash
# Fill missing 720/1080 without flipping ready → pending
php artisan videos:backfill-media --upgrade-ladder --limit=500

# Remux ladder MP4s still missing moov-at-front
php artisan videos:backfill-media --reencode-faststart --heights=360,720,1080 --limit=500

# Spot-check Range / fast-start / even dims / url_720
php artisan videos:validate-media --sample=20 --api-check
```

New uploads pick up the pipeline automatically.

## After upload

- `POST /api/videos/create` returns `video_id` + decorated video immediately (`transcode_status: pending`, `processing_status: processing`).
- Poll `GET /api/videos/processing_status?video_id={id}` until both are `"ready"`, or refresh profile/reels.
- Poll response includes full media fields: `hls_playlist_url`, `video_sources`, `thumbnail_url`, etc. — same shape as feed items.
- Until ready, client must not treat raw upload dimensions as playback (odd axes caused Honor surface stalls when `url_720` was missing).

## Profile avatars

- Use `image_url` / `user.image` from API as **absolute URLs** — do not prepend `media_base_url`.
- Correct CDN path: `https://cdn.cookster.org/storage/front_users/{filename}.jpg`
- Don't fix 404s client-side by swapping `/storage/front_users/` vs `/front_users/` — backend normalizes; if 404, show default avatar.

## Preload behavior (mobile)

- Prefetch visible + next 2–4 reels when ready; prefer **720 then 1080** on disk.
- Keep poster visible until first decoded frame.
- Respect Remote Config (`reels_preload_enabled`, data saver).

## What not to do

- Don't mark a reel playable from HLS/ladder until `transcode_status == "ready"` (and `url_720` is present).
- Don't construct CDN paths from raw DB filenames.
- Don't double-prefix URLs with `media_base_url` when value already starts with `https://`.
- Don't open the raw upload MP4 when ladder URLs exist — that path caused `406×721`-style surface churn.

## Example ready item

```json
{
  "id": "uuid",
  "transcode_status": "ready",
  "processing_status": "ready",
  "playback_ready": true,
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

Use absolute CDN URLs from the API; when ready prefer **cached/partial `url_720`** (upgrade to 1080 on Wi‑Fi when cached); show sharp `thumbnail_url` until first frame; never play raw upload axes once the ladder exists; flip `reels_hls_wifi_enabled` later for adaptive HLS without another transcoder change.
