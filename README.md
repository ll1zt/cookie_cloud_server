# CookieCloud Server (Elixir)

An Elixir implementation of the [CookieCloud](https://github.com/easychen/CookieCloud) server. It allows you to synchronize and manage browser cookies securely.

## Features

- **End-to-End Encryption**: Supports Legacy and AES-128-CBC encryption modes.
- **SQLite3 Backend**: easy-to-manage storage for your sync records.
- **Netscape Format Export**: Export cookies in the standard Netscape format (`cookies.txt`) for use with CLI tools.
- **Modern Web Stack**: Powered by [Bandit](https://github.com/mtrudel/bandit) and [Plug](https://github.com/elixir-plug/plug).
- **Nix Powered**: Fully reproducible development environment and Docker builds via Nix Flakes.

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
   Enter the development shell:
   ```bash
   nix develop
   ```
   Or run the server directly:
   ```bash
   COOKIE_CLOUD_SERVER_PASSWORD="your-password" nix run . -- start
   ```

3. **Using Mix (Manual)**:
   ```bash
   mix deps.get
   ```

## Configuration

Set the following environment variables. You can use a `.env` file (see `.env.example`).

| Variable | Description | Default |
| :--- | :--- | :--- |
| `COOKIE_CLOUD_SERVER_PASSWORD` | **Required**. Password for decryption and API auth. | - |
| `PORT` | The port the server listens on. | `4000` |
| `DATABASE_PATH` | Path to the SQLite database file. | `data/cookie_cloud_server.db` |
| `RELEASE_COOKIE` | Secret for Elixir node clustering. | `cookie` |

## Deployment

### Docker Compose (Recommended)

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   # Edit .env and set your COOKIE_CLOUD_SERVER_PASSWORD
   ```

2. Start the server:
   ```bash
   docker compose up -d
   ```

The image is automatically built and pushed to GitHub Container Registry (GHCR) using Nix for maximum consistency.

### Manual Build (Nix)

To build a production Docker image tarball locally:
```bash
nix build .#docker
docker load < result
```

## API Endpoints

### 1. Root
- **GET** `/`
- Returns a simple greeting.

### 2. Update Cookies
- **POST** `/update`
- Body: `{"uuid": "...", "encrypted": "...", "crypto_type": "..."}`
- Syncs and updates cookies for the given UUID.

### 3. Get Cookies
- **GET** `/get/:uuid?token=<PASSWORD>&format=<FORMAT>&domain=<DOMAIN>`
- **Authorization**: Requires the `COOKIE_CLOUD_SERVER_PASSWORD` as a token (via query param `token` or `Authorization: Bearer <token>` header).
- **Parameters**:
  - `format`: `raw` (default) or `netscape`.
  - `domain`: Optional domain filter (e.g., `google.com`).
