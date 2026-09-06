# Partner QR rewards — Flutter contract

Canonical server behavior is on Laravel (`/api/rewards/*`). Profile-share QR
and any older one-time discount QR stay unchanged.

Auth: `Authorization: Bearer {token}` on every route.
Partner mutations require `entity == 2`. Scan is one DB transaction
(lock deal → unique redeem → decrement → exhaust at 0).
Create/renew activate immediately (`payment_status=waived`).
Scan rate limit: 10/min per partner.

## Endpoints

| Method | Path | Who | Body |
|---|---|---|---|
| GET | `/api/rewards/my-code` | any signed-in user | — |
| GET | `/api/rewards/deals/current` | partner | — |
| POST | `/api/rewards/deals` | partner | `{ "title", "quantity" }` |
| POST | `/api/rewards/deals/renew` | partner | `{ "title", "quantity" }` |
| POST | `/api/rewards/deals/pause` | partner | `{}` |
| POST | `/api/rewards/scan` | partner | `{ "token" }` |
| GET | `/api/rewards/deals/history` | partner | — |

`token` is the full QR string (`cookster_redeem:<hmac>`). HMAC expires in 60s.
No raw user id is encoded.

## Success shapes (also accepted under `data`)

**my-code**

```json
{
  "status": true,
  "payload": "cookster_redeem:<hmac>",
  "expires_in": 60,
  "eligible": true
}
```

**current / create / renew / pause / scan**

```json
{
  "status": true,
  "error_code": "success",
  "deal": {
    "id": "...",
    "title": "Coffee",
    "quantity_total": 100,
    "quantity_remaining": 99,
    "status": "active"
  }
}
```

No deal yet: `deal` is `null`. History: `deals: [ ... ]`.

## `error_code` (Flutter maps each to a locale key)

`success`, `already_redeemed`, `deal_exhausted`, `deal_paused`,
`no_active_deal`, `invalid_or_expired_token`, `not_a_partner`,
`cannot_redeem_own_qr`, `active_deal_exists`, `partner_blocked`,
`rate_limited`.

HTTP 429 is treated as `rate_limited`.
