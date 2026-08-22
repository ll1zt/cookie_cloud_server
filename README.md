# CookieCloud Server (Elixir)

An Elixir implementation of the [CookieCloud](https://github.com/easychen/CookieCloud) server. Compatible with the official browser extension and client scripts, with optional server-side decrypt cache and export helpers.

## Features

- **CookieCloud protocol compatible**: stores ciphertext by default (true E2E-friendly sync relay).
- **Legacy + AES-128-CBC-fixed** crypto modes.
- **Optional admin decrypt/export** when `COOKIE_CLOUD_SERVER_PASSWORD` is set (`raw` / `full` / `netscape`).
- **SQLite3 Backend** via Ecto.
- **API_ROOT / CORS / rate limit / health** for production self-hosting.
- **Modern Web Stack**: [Bandit](https://github.com/mtrudel/bandit) + [Plug](https://github.com/elixir-plug/plug).
- **Nix Powered**: reproducible dev shell and Docker image via Flakes.

## Getting Started

### Prerequisites

- Elixir 1.18 or later
- Erlang/OTP 26 or later
- **Alternatively**: Just [Nix](https://nixos.org/download.html) (highly recommended)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/ll1zt/cookie_cloud_server.git
   cd cookie_cloud_server
   ```

2. **Using Nix (Recommended)**:
   ```bash
   nix develop
   # or
   COOKIE_CLOUD_SERVER_PASSWORD="your-password" nix run . -- start
   ```

3. **Using Mix (Manual)**:
   ```bash
   mix deps.get
   mix run --no-halt
   ```

## Configuration

Set environment variables (see `.env.example`). `.env` lines may be either `KEY=value` or `export KEY=value` when loaded by Mix.

| Variable | Description | Default |
| :--- | :--- | :--- |
| `COOKIE_CLOUD_SERVER_PASSWORD` | Optional. Enables decrypt-cache + admin Bearer export. | unset (ciphertext-only mode) |
| `PORT` | Listen port. Official project often uses `8088`. | `4000` |
| `DATABASE_PATH` | SQLite file path. | `data/cookie_cloud_server.db` |
| `API_ROOT` | Optional URL prefix, e.g. `/cookie`. | empty |
| `CORS_ORIGINS` | `Access-Control-Allow-Origin` value. | `*` |
| `RATE_LIMIT_MAX` | Max requests per IP per window (`0` disables). | `100` |
| `RATE_LIMIT_WINDOW_MS` | Rate limit window in ms. | `900000` (15m) |
| `RATE_LIMIT_SWEEP_INTERVAL_MS` | Sweep interval for expired rate-limit windows. | window value |
| `TRUST_PROXY` | Honour `X-Forwarded-For`; set to `true` only behind a trusted reverse proxy. | `false` |
| `RELEASE_COOKIE` | Elixir node cookie. | `cookie` |

## Deployment

### Docker Compose (Recommended)

```bash
cp .env.example .env
# edit .env
docker compose up -d
```

Image is built and pushed to GHCR via Nix on `main`.

### Manual Build (Nix)

```bash
nix build .#docker
docker load < result
```

## API Endpoints

### Root
- **GET** `/` — greeting
- **GET** `/health` — `{"status":"OK","timestamp":"...","uptime":...}`

### Update (official compatible)
- **POST** `/update`
- Body (JSON, form-urlencoded, or multipart): `uuid`, `encrypted`, optional `crypto_type` (`legacy` \| `aes-128-cbc-fixed`)
- Always stores **ciphertext**. If server password can decrypt, also refreshes optional plaintext cache. Decrypt failure does **not** fail the upload.
- Response: `{"action":"done"}`

### Get (official compatible + admin export)

- **GET|POST** `/get/:uuid`

| Mode | How | Response |
| :--- | :--- | :--- |
| Ciphertext (default) | no password / no admin token | `{"encrypted":"...","crypto_type":"..."}` |
| Client decrypt | body/query `password` | decrypted full payload |
| Admin export | `Authorization: Bearer <COOKIE_CLOUD_SERVER_PASSWORD>` or `?token=` | see formats below |

Admin query params:
- `format`:
  - `raw` — flat cookie list JSON
  - `full` — entire decrypted object
  - `netscape` — `cookies.txt`
  - `header` — `name=value; name2=value2` (**RSSHub / curl Cookie header**)
  - `env` — one dotenv line: `ENV=name=value; ...` (for RSSHub `secretFiles`)
- `domain`: optional domain filter (e.g. `bilibili.com`)
- `env`: env var name when `format=env` (default `COOKIE`)
- `crypto_type`: optional override for client decrypt path

### RSSHub integration

RSSHub reads platform cookies from environment variables such as `BILIBILI_COOKIE_<uid>`, `ZHIHU_COOKIES`, etc. (see [RSSHub config](https://docs.rsshub.app/zh/deploy/config)).

With this server (password set + browser extension synced using the **same** password):

```bash
# Cookie header only
curl -sS -H "Authorization: Bearer $COOKIE_CLOUD_SERVER_PASSWORD" \
  "http://127.0.0.1:4000/get/$UUID?format=header&domain=bilibili.com"

# Direct dotenv line for /etc/secrets/rsshub.env (or append into secretFiles)
curl -sS -H "Authorization: Bearer $COOKIE_CLOUD_SERVER_PASSWORD" \
  "http://127.0.0.1:4000/get/$UUID?format=env&domain=bilibili.com&env=BILIBILI_COOKIE_12345678" \
  >> /etc/secrets/rsshub.env
```

NixOS example (`secretFiles = [ "/etc/secrets/rsshub.env" ];`): refresh that file periodically (cron/systemd timer) from CookieCloud, then restart or reload RSSHub if your module does not watch the file.

Recommended flow:
1. Browser CookieCloud extension → this server (`/update`, ciphertext + optional decrypt cache)
2. Timer pulls `format=header|env` for each site
3. Write RSSHub secret env file → RSSHub uses cookies on next request

## Compatibility notes

This server can be used as a drop-in host for the official CookieCloud extension and scripts (`examples/decrypt.py`, Playwright helpers): they upload ciphertext and download ciphertext (or decrypt locally / with client password).

Admin export features are **extras** for automation (e.g. RSSHub) when you intentionally share the sync password with the server.

## Development

```bash
mix test
```
