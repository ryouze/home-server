# Docker

I want to use Docker to manage all of my user-facing apps because it provides isolation from the underlying OS and makes removing them easy, which is good for experimentation.

## Install Docker

I need to set up Docker for all of my home server services.

1. I followed the official Docker guide for the APT installation method: https://docs.docker.com/engine/install/debian/#install-using-the-repository
2. After installation, I followed a guide that avoids having to use `sudo`: https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
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

I originally wanted to have one `compose.yaml` file within each directory and then one global `compose.yaml` that imports them. However, I later realized that this much indirection was not worth it for a simple home server.

1. I created the following layout using `sudo` (`/srv/storage` was set up in the previous "NAS" step):
    ```sh
    .
    |-- .env
    |-- compose.yaml
    |-- caddy
    |   |-- conf
    |   |   `-- Caddyfile
    |   |-- config
    |   `-- data
    |-- dashy
    |   `-- user-data
    |-- filebrowser
    |   |-- config
    |   `-- database
    |-- pihole
    |   `-- etc-pihole
    |-- jellyfin
    |   |-- cache
    |   `-- config
    |-- qbittorrent
    |   `-- config
    |-- prowlarr
    |   `-- config
    |-- radarr
    |   `-- config
    |-- sonarr
    |   `-- config
    |-- bazarr
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
2. I set the owner to my user (`void`) instead of `root` again:
    ```sh
    sudo chown -R void:void /srv
    ```

## Docker Compose setup

> [!WARNING]
> The per-container steps are written in the exact chronological order in which I originally performed them. The files in `config/`, however, reflect the latest finalized setup, so keep that in mind as you continue reading.

I need to put all of my services in the `compose.yaml` file.

1. I set `/srv/compose.yaml` to `configs/compose.yaml` via `nano`. I omitted the `Caddy` setup on the first run, so the `8096:8096/tcp` port mapping needs to be added to `/srv/compose.yaml` for Jellyfin and `8080:8080` for qBittorrent.
2. Inside `/srv`, I ran `docker compose config` to verify that my config was set up correctly.
3. Still inside `/srv`, I ran `docker compose up -d` to start all containers.

## qBittorrent setup

1. I logged in with `admin` and the temporary password listed by `docker compose logs qbittorrent`.
2. In the top bar, I clicked `Tools` -> `Options` and then opened the `WebUI` tab.
3. Under the `Authentication` tab, I changed the username to `void` and generated a password with my password manager.
4. Under the `Behavior` tab, I set the action on double-click to `No action`. I prefer the explicit right-click menu for managing torrents.
5. Under the `Downloads` tab, I set `Torrent content layout` to `Create subfolder` and enabled `Add to top of queue`. This is crucial for Jellyfin detection, as each movie and TV series should be in its own directory. I also enabled `Append .!qB extension to incomplete files` and `Keep unselected torrent files in ".unwanted" folder`. Finally, I set the `Default Save Path` to `/data/temp/complete`, enabled `Keep incomplete torrents in`, and set it to `/data/temp/incomplete`.
6. Under the `BitTorrent` tab, I set `Maximum active downloads` to `4`, `Maximum active uploads` to `10`, and `Maximum active torrents` to `16`.

## Jellyfin setup

1. I opened Safari and went to `debian.local:8096`.
2. I set the server name to `debian` and the preferred display language to `English`.
3. I set the default (admin) username to `void` and generated a password using my password manager.
4. I added my Movies (`data/movies`) and TV series (`data/tv`) libraries. I set the language to `English` and the region to `United States`. I also enabled metadata refresh every 90 days.
5. I set the preferred metadata language to `English` and the region to `United States`.
6. I left `Allow remote connections to this server` enabled.
7. After the main page loaded, I clicked the profile icon in the top-right corner and clicked `Dashboard` (Administration).
8. I opened the `General` tab and set `Enable QuickConnect on this server` to `False`.
9. I opened the `Branding` tab, enabled `Enable the splash screen image`, and entered custom CSS code from this repository: https://github.com/loof2736/scyfin
10. I opened `Users` and created non-root user accounts, disabling `Hide this user from login screens`.
11. I opened the `Playback` -> `Transcoding` tab and set hardware acceleration to `Intel Quicksync (QSV)`. I then ran `docker exec -it jellyfin /usr/lib/jellyfin-ffmpeg/vainfo` to retrieve supported codecs, and under `Enable hardware decoding for`, I checked everything except `AV1`, `HEVC RExt 8/10bit`, and `HEVC RExt 12bit`. Refer to the docs: https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel#configure-with-linux-virtualization
12. I verified that the hardware acceleration was working correctly, as described here: https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel#verify-on-linux

## Caddy setup

1. I set `/srv/caddy/conf/Caddyfile` to `configs/Caddyfile` via `nano`.
2. I re-added the `caddy` container to `/srv/compose.yaml`, this time without the port mapping for Jellyfin and qBittorrent.
3. In the Jellyfin `Dashboard` (Administration) (see `## Jellyfin setup`), I opened the `Networking` tab, set the `Base URL` to `/jellyfin`, and clicked `Save` at the bottom.
4. I ran `docker compose down` and `docker compose up -d` for a clean restart.
5. In the Jellyfin `Dashboard` (Administration) (see `## Jellyfin setup`), I opened the `Networking` tab and set `Known Proxies` to the output of `docker network inspect srv_default --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'` (e.g., `123.12.0.3`). When traffic passes through a reverse proxy, Jellyfin will otherwise see the proxy's IP instead of the client's IP.

## Dashy setup

1. I set `/srv/dashy/user-data/conf.yml` to `configs/conf.yml` via `nano`.
2. I ran `docker compose down` and `docker compose up -d` for a clean restart.

## Pi-hole setup

1. I set `/srv/caddy/conf/Caddyfile` to `configs/Caddyfile` via `nano` again.
2. I appended `PIHOLE_WEB_PASSWORD=replace_me` to `/srv/.env`, where `replace_me` is the output from my password manager.
3. I ran `docker compose down` and `docker compose up -d` for a clean restart.
4. I opened Safari and went to `http://debian.local/pihole/admin/`, logging in with my password to check that the web UI works.
5. I ran `dig @127.0.0.1 doubleclick.net` to check whether the ad domain would return `0.0.0.0`. I also ran `dig @192.168.1.67 doubleclick.net` from my MacBook, expecting `0.0.0.0` there too.
6. I logged into my router (see `#1_debian.md` for more information) and changed both my primary and secondary DNS servers to `192.168.1.67`.

## File Browser setup

1. I ran `docker logs filebrowser` to retrieve the randomly generated password.
2. I opened Safari and went to `http://debian.local/files/`, logging in with this password.
3. I clicked the `Settings` sidebar, selected the `User Management` tab, clicked the `Edit` button next to the default `admin` account, and then changed its username to `void` and password to the one from my password manager.
4. Still in the settings, I selected the `Global Settings` tab, set the `Minimum password length` to `20`, and set the `Instance name` to `debian.local`.

## Arr setup

1. I started the containers once so they could generate config files:
    ```sh
    docker compose up -d sonarr radarr prowlarr bazarr
    # Wait a bit, then:
    docker compose stop sonarr radarr prowlarr bazarr
    ```
2. I edited the generated config files:
    `nano /srv/sonarr/config/config.xml`: Replace `<UrlBase></UrlBase>` with `<UrlBase>/sonarr</UrlBase>`
    `nano /srv/radarr/config/config.xml`: Replace `<UrlBase></UrlBase>` with `<UrlBase>/radarr</UrlBase>`
    `nano /srv/prowlarr/config/config.xml`: Replace `<UrlBase></UrlBase>` with `<UrlBase>/prowlarr</UrlBase>`
    `nano /srv/bazarr/config/config/config.yaml`: Replace `base_url: ''` with `base_url: '/bazarr'`
3. I restarted everything via `docker compose down && docker compose up -d`.
4. I logged into qBittorrent at `http://debian.local/qbt/` and, on the left sidebar, right-clicked inside the `Categories` area and created two categories:
    - Name: `sonarr`, Save path: (Blank)
    - Name: `radarr`, Save path: (Blank)
5. I went to `http://debian.local/sonarr/` and in the `Authentication Required` modal, I selected:
   - Authentication Method: `Forms (Login Page)`
   - Authentication Required: `Enabled`
   - Username: `void`
   - Password: (Generated by my password manager)
6. I also set up authentication for `http://debian.local/radarr/` and `http://debian.local/prowlarr/`.
7. I went back to `http://debian.local/sonarr/`, opened `Settings` -> `Download Clients` from the left sidebar, clicked the plus button, and added `qBittorrent` with the following settings:
   - Host: `qbittorrent`
   - Port: `8080`
   - Username: `void`
   - Password: (Taken from my password manager)
   - Category: `sonarr`
   - Remove Completed: Unchecked
8. I added `qBittorrent` as a download client in `http://debian.local/radarr/` using the same settings, with the category set to `radarr`.
9. In both Sonarr and Radarr, I opened `Settings` -> `General` and copied the `API Key`. Then in Prowlarr, under `Settings` -> `Apps`, I clicked the plus symbol and added Sonarr with the following settings:
    - Name: `Sonarr`
    - Sync Level: `Full Sync`
    - Tags: `sonarr`
    - Prowlarr Server: `http://prowlarr:9696/prowlarr`
    - Sonarr Server: `http://sonarr:8989/sonarr`
    - API Key: (Sonarr API key)
   I also added Radarr with the following settings:
   - Name: `Radarr`
   - Sync Level: `Full Sync`
   - Tags: `radarr`
   - Prowlarr Server: `http://prowlarr:9696/prowlarr`
   - Radarr Server: `http://radarr:7878/radarr`
   - API Key: (Radarr API key)
10. Still in Prowlarr, in the left sidebar, I opened `Indexers` and clicked `Add indexer`. I then added the following: `AnimeTosho` (Tags: `radarr`, `sonarr`), `LimeTorrents` (Tags: `sonarr`, `radarr`), `The Pirate Bay` (Tags: `sonarr`, `radarr`), `showRSS` (Tags: `sonarr`), `TorrentGalaxyClone` (Tags: `sonarr`, `radarr`), and `YTS` (Tags: `radarr`).
11. In Sonarr, under `Settings` -> `Media Management`, I clicked `Add Root Folder` and entered `/data/tv/`, then checked `Rename Episodes`. I did the same for Radarr, setting it to `/data/movies`.
12. I went to `http://debian.local/bazarr/` and, on the left sidebar, selected `Settings` and entered the following:
   - Authentication Method: `Forms`
   - Authentication Required: `Enabled`
   - Username: `void`
   - Password: (Generated by my password manager)
13. Still in Bazarr, on the left sidebar, I selected `Radarr`, checked `Enabled`, and set the following:
    - Address: `radarr`
    - Port: `7878`
    - Base URL: `radarr`
    - API Key: (Radarr API key)
    - Download Only Monitored: `disabled`
    For Sonarr, I used the following:
    - Address: `sonarr`
    - Port: `8989`
    - Base URL: `sonarr`
    - Download Only Monitored: `disabled`
14. Still in Bazarr, on the left sidebar, I selected `Subtitles` and set `Languages Filter` to `English`. Under `Languages Profile`, I then clicked `Add New Profile` and set `Name` to `English` and `tag` to `english`. Then, under `Default Language Profiles For Newly Added Shows`, I checked both `Series` and `Movies` and set them to `English`.

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
