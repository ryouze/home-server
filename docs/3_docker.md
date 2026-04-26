# Docker

I want to use Docker for managing all of my user-facing apps because it provides isolation from the underlying OS and makes removing them easy, so it's good for experimentation.

## Install Docker

I need to set up Docker for all of my home server services.

1. I followed the official Docker guide for the APT installation method: https://docs.docker.com/engine/install/debian/#install-using-the-repository
2. After installation, I followed a guide that avoids having to add `sudo`: https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
3. I created a config that rotates the log files via `sudo nano /etc/docker/daemon.json`:
    ```json
    {
        "log-driver": "local",
        "log-opts": {
            "max-size": "10m"
        }
    }
    ```

## File layout

I originally wanted to have one `compose.yaml` file within each directory and then one global `compose.yaml` that imports them. However, I later realized that this much indirection is not worth it for a simple home server.

1. I created the following layout using `sudo` (the `/srv/storage` was set up in the previous "NAS" step):
    ```sh
    .
    |-- .env
    |-- compose.yaml
    |-- caddy
    |   |-- conf
    |   |   `-- Caddyfile
    |   |-- config
    |   `-- data
    |-- homarr
    |   `-- appdata
    |-- pihole
    |   `-- etc-pihole
    |-- jellyfin
    |   |-- cache
    |   `-- config
    |-- qbittorrent
    |   `-- config
    `-- storage
        `-- data
            |-- dev
            |-- games
            |-- misc
            |-- movies
            |-- temp
            `-- tv
    ```
2. I set the owner to my user (`void`) instead of root again:
    ```sh
    sudo chown -R void:void /srv
    ```

## Docker Compose setup

> [!WARNING]
> The per-container steps are written in the exact chronological order as I originally did them. The files in `config/`, however, reflect the latest finalized setup, so keep that in mind as you continue reading.

I need to put all of my services in the `compose.yaml` file.

1. I set `/srv/compose.yaml` to `configs/compose.yaml` via `nano`. I omitted the `Caddy` setup on the first run, so the `8096:8096/tcp` port mapping needs to be added to `/srv/compose.yaml` for Jellyfin and `8080:8080` for qBittorrent.
2. Inside `/srv`, I ran `docker compose config` to verify that my config is set up correctly.
3. Still inside `/srv`, I ran `docker compose up -d` to start all containers.

## qBittorrent setup

1. I logged in with `admin` and the temporary password listed by `docker compose logs qbittorrent`.
2. In the top bar, I clicked `Tools` -> `Options` and then opened the `WebUI` tab.
3. Under the `Authentication` tab, I changed the username to `void` and generated a password with my password manager.
4. Under the `Behavior` tab, I set the action on double-click to `No action`. I prefer the explicit right-click menu for managing torrents.
5. Under the `Downloads` tab, I set `Torrent content layout` to `Create subfolder`. This is crucial for Jellyfin detection, as each movie and TV series should be in its own directory. I also set the `Default Save Path` to `/data/movies`, enabled `Keep incomplete torrents in`, and set it to `/data/temp`.

## Jellyfin setup

1. I opened Safari and went to `debian.local:8096`.
2. I set the server name to `debian` and the preferred display language to `English`.
3. I set the default (admin) username to `void` and generated a password using my password manager.
4. I added my Movies (`data/movies`) and TV series (`data/tv`) libraries. I set the language to `English` and the region to `United States`. I also enabled metadata refresh every 90 days.
5. I selected the preferred metadata language to `English` and the region to `United States`.
6. I left `Allow remote connections to this server` enabled.
7. After the main page loaded, I clicked the profile icon in the top right corner and clicked `Dashboard` (Administration).
8. I opened the `General` tab and set `Enable QuickConnect on this server` to `False`.
9. I opened the `Branding` tab, set `Enable the splash screen image` to enabled, and entered custom CSS code from this repository: https://github.com/loof2736/scyfin
10. I opened `Users` and created non-root user accounts, disabling `Hide this user from login screens`.
11. I opened the `Playback` -> `Transcoding` tab and set hardware acceleration to `Intel Quick Sync (QSV)`. I then ran `docker exec -it jellyfin /usr/lib/jellyfin-ffmpeg/vainfo` to retrieve supported codecs, and under `Enable hardware decoding for`, I checked everything except `AV1`, `HEVC RExt 8/10bit`, and `HEVC RExt 12bit`. Refer to docs: https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel#configure-with-linux-virtualization
12. I verified that the hardware acceleration is working correctly, as described here: https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel#verify-on-linux

## Caddy setup

1. I set `/srv/caddy/conf/Caddyfile` to `configs/Caddyfile` via `nano`.
2. I re-added the `caddy` container to `/srv/compose.yaml`, this time without the port mapping for Jellyfin and qBittorrent.
3. In the Jellyfin `Dashboard` (Administration) (see `##Jellyfin-setup`), I opened the `Networking` tab and set the `Base URL` to `/jellyfin` and clicked `Save` at the bottom.
4. I ran `docker compose down` and `docker compose up -d` for a clean restart.
5. In the Jellyfin `Dashboard` (Administration) (see `##Jellyfin-setup`), I opened the `Networking` tab and set `Known Proxies` to the output of `docker network inspect srv_default --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'` (e.g., `123.12.0.3`). When traffic passes through a reverse proxy, Jellyfin will otherwise see the proxy's IP instead of the client's IP.

## Homarr setup

1. I created a `.env` file at `/srv/.env` and set it to `SECRET_ENCRYPTION_KEY=replace_me`, where `replace_me` is the output of `openssl rand -hex 32`, as seen in `configs/.env.example`.
2. I ran `docker compose down` and `docker compose up -d` for a clean restart.
3. I opened Safari and went to `debian.local`.
4. I left the language as `English (US)`, set the theme to `Dark`, and clicked `Start from scratch`.
5. I used my password manager to generate a strong user password.
6. I left analytics enabled to support open source and disabled all search crawling.
7. I clicked `Create your first board`, clicked `New board`, and called it `home-server`, marking it as public.
8. In the sidebar on the left, I clicked `Integrations`.
9. I clicked `New integration` and selected `Jellyfin`, then entered the following:
    - Name: `Jellyfin` (default)
    - URL: `http://jellyfin:8096/jellyfin`
    - API Key: (I had to sign in to my Jellyfin admin dashboard, then under the `API Keys` tab in the sidebar, I generated a new API key called `Homarr`)
    - Create app: `Enabled`
    - App URL: `http://debian.local/jellyfin/`
10. I clicked `New integration` again and selected `qBittorrent`, then entered the following:
    - Name: `qBittorrent` (default)
    - URL: `http://qbittorrent:8080`
    - Username & Password: (I took them from my password manager)
    - Create app: `Enabled`
    - App URL: `http://debian.local/qbt/`
11. In the sidebar on the left, I clicked `Settings`, and under `Global home board`, I set `home-server` as both the `Global home board` and the `Global mobile board`, then clicked `Save`. I also set `Appearance` to `Dark`.
12. In the sidebar, I clicked `Boards` and within `home-server`, I clicked `Open board`.
13. I clicked the `Edit mode` button in the top right corner, then selected `Add an app` from the submenu. I added both `Jellyfin` and `qBittorrent` that way.
14. I clicked the `Edit mode` button again, this time selecting `New item`, then I selected `Media releases`. I clicked `Edit item` on the new item and set `Integrations` to `Jellyfin`.
15. I did the same, but with `Download Client` for `qBittorrent`.
16. I clicked the `Settings` button in the top right corner. I then did the following:
    - In the `General` expander, I set the `Page title` and the `Meta title` to `Home Server`. I also set the `Logo image URL` and `Favicon image URL` to Debian.
    - In the `Layout` expander, I created three layouts:
      - Small: breakpoint `0`, `2` columns
      - Medium: breakpoint `768`, `6` columns
      - Large: breakpoint `1200`, `8` columns
    - In the `Background` expander, I set the background to a custom image.
    - In the `Appearance` expander, I set the opacity to `70%`.
17. I resized my physical web browser's width and adjusted the icon positions.

## Pi-hole setup

1. I set `/srv/caddy/conf/Caddyfile` to `configs/Caddyfile` via `nano` again.
2. I appended `PIHOLE_WEB_PASSWORD=replace_me` to `/srv/.env`, where `replace_me` is the output of my password manager.
3. I ran `docker compose down` and `docker compose up -d` for a clean restart.
4. I opened Safari and went to `http://debian.local/pihole/admin/`, logging in with my password to check that the web UI works.
5. I ran `dig @127.0.0.1 doubleclick.net` to check if the ad domain will return `0.0.0.0`. I also ran `dig @192.168.1.67 doubleclick.net` from my MacBook, expecting `0.0.0.0` too.
6. I logged into my router (see `#1_debian.md` for more information) and changed both my primary and secondary DNS to `192.168.1.67`.
7. I added Pi-hole to Homarr:
    - Name: `Pi-hole` (default)
    - URL: `http://pihole`
    - API Key: (same as in `PIHOLE_WEB_PASSWORD`)
    - Create app: `Enabled`
    - App URL: `http://debian.local/pihole/admin/`


```md
qBittorrent app-side settings:

Go to `Tools -> Options -> WebUI`.

Set the bind IP to `*`. qBittorrent's Caddy guide says to leave the IP set to `*`. This matters because Caddy will connect from another container, not from qBittorrent itself. ([GitHub][5])

Set the WebUI port to `8080`, since that is what your compose file already uses.

Turn off `Use UPnP / NAT-PMP to forward the port from my router`. qBittorrent's guide explicitly says to disable it. ([GitHub][5])

Turn off `Use HTTPS instead of HTTP`. Since Caddy is the reverse proxy in front, qBittorrent's own guide explicitly says to leave qBittorrent on HTTP behind the proxy. ([GitHub][5])

Turn on `Clickjacking protection` and `CSRF protection`. qBittorrent's Caddy guide explicitly says to enable both. ([GitHub][5])

Turn on `Host header validation`. qBittorrent's Caddy guide says to enable it and confirm `*; example.domain` is present in the `server domains` box. The qBittorrent WebUI API describes this field as a semicolon-separated list of domains accepted when performing Host header validation. For your LAN-only setup, the practical version is something like `*; 192.168.1.50; media.lan` if those are the names you use. ([GitHub][5])

Do not enable qBittorrent's built-in HTTPS for this setup. Also do not add a `Secure` cookie rule in Caddy for this HTTP-only LAN setup. qBittorrent's reverse-proxy docs warn that forcing the cookie `Secure` flag while the external site is only HTTP causes login loops. ([GitHub][3])

If qBittorrent gives `Unauthorized` or login-loop behavior, the usual cause is the WebUI security settings not matching the reverse proxy setup, especially host header validation, server domains, or an HTTP/HTTPS mismatch.
```
