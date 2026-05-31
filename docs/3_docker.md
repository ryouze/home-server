# Docker

I want to use Docker to manage all of my user-facing apps because it provides isolation from the underlying OS and makes removing them easy, which is good for experimentation.

## Install Docker

I need to set up Docker for all of my home server services.

1. I followed the official Docker guide for the APT installation method: https://docs.docker.com/engine/install/debian/#install-using-the-repository
2. After installation, I followed a guide that avoids having to use `sudo`: https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
3. I created a config that rotates log files via `sudo nano /etc/docker/daemon.json`:
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
            |-- media
            |   |-- movies
            |   `-- tv
            |-- other
            |   |-- dev
            |   `-- games
            `-- torrents
                |-- movies
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
3. Under the `Authentication` tab, I changed the username to `void` and generated a password with my password manager. I also set the `Session timeout` to `0` seconds (never log out).
4. Under the `Behavior` tab, I set the action on double-click to `No action`. I prefer the explicit right-click menu for managing torrents.
5. Under the `Downloads` tab, I set `Torrent content layout` to `Create subfolder` and enabled `Add to top of queue`. This is crucial for Jellyfin detection, as each movie and TV series should be in its own directory. I also enabled `Delete .torrent files afterwards`, `Append .!qB extension to incomplete files`, and `Keep unselected torrent files in ".unwanted" folder`. Finally, I set the `Default Save Path` to `/data/torrents`. I also set the following in the `Saving Management` section:
    - Default Torrent Management Mode: `Automatic`
    - When Torrent Category changed: `Relocate torrent`
    - When Default Save Path changed: `Relocate affected torrents`
    - When Category Save Path changed: `Relocate affected torrents`
6. Under the `Connection` tab, I set `Global maximum number of upload slots` to `8`.
7. Under the `BitTorrent` tab, I set `Maximum active downloads` to `4`, `Maximum active uploads` to `10`, and `Maximum active torrents` to `16`.
8. I later added the VueTorrent Docker mod to `compose.yaml` and ran `docker compose up -d --force-recreate qbittorrent`. Then, in the `WebUI` tab, I enabled `Use alternative WebUI` and set the `Files location` to `/vuetorrent`.

## Jellyfin setup

1. I opened Safari and went to `debian.local:8096`.
2. I set the server name to `debian` and the preferred display language to `English`.
3. I set the default (admin) username to `void` and generated a password using my password manager.
4. I added my Movies (`data/media/movies`) and TV series (`data/media/tv`) libraries. I set the language to `English` and the region to `United States`. I also enabled metadata refresh every 90 days.
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
6. In the qBittorrent `WebUI` tab, I checked `Enable reverse proxy support` and set it to the output of `docker network inspect srv_default --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'` again.

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

## Servarr setup

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
    - Name: `sonarr`, Save path: `/data/torrents/tv`
    - Name: `radarr`, Save path: `/data/torrents/movies`
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
    - Remove Completed: Checked
8. I added `qBittorrent` as a download client in `http://debian.local/radarr/` using the same settings, with the category set to `radarr`.
9. In both Sonarr and Radarr, I opened `Settings` -> `General` and copied the `API Key`. Then, in Prowlarr, under `Settings` -> `Apps`, I clicked the plus symbol and added Sonarr with the following settings:
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
    Under sync profiles, I clicked `Standard` and set the `Minimum Seeders` to `5`.
10. Still in Prowlarr, in the left sidebar, I opened `Indexers` and clicked `Add indexer`. I then added the following: `AnimeTosho` (Tags: `radarr`, `sonarr`), `LimeTorrents` (Tags: `sonarr`, `radarr`), `The Pirate Bay` (Tags: `sonarr`, `radarr`), `showRSS` (Tags: `sonarr`), `TorrentGalaxyClone` (Tags: `sonarr`, `radarr`), and `YTS` (Tags: `radarr`). I also set the `Seed Ratio` to `2` for each indexer.
11. In Sonarr, under `Settings` -> `Media Management`, I clicked `Add Root Folder` and entered `/data/media/tv/`, then checked `Rename Episodes`, `Create Empty Series Folders`, and `Unmonitor Deleted Episodes`. I set `Propers and Repacks` to `Do not Prefer`. I did the same for Radarr, setting it to `/data/media/movies`. I also added the recommended naming schemes for Sonarr and Radarr from here: https://trash-guides.info/Sonarr/Sonarr-recommended-naming-scheme/. I also checked `Import extra files` and set them to `srt,ass,ssa,sub,idx,nfo` for both Sonarr and Radarr.
12. In `Settings` -> `Custom Formats`, I clicked the plus button. I then imported `AV1`, `BR-DISK`, `LQ`, `LQ (Release Title)`, `Upscaled`, and `Extras`, and followed the rest of the guide at https://trash-guides.info/Sonarr/sonarr-setup-quality-profiles/#web-1080p.
13. I did the same custom format setup for Radarr using the following guide: https://trash-guides.info/Radarr/radarr-setup-quality-profiles/#hd-bluray-web
14. I went to `http://debian.local/bazarr/` and, on the left sidebar, selected `Settings` and entered the following:
    - Authentication Method: `Forms`
    - Authentication Required: `Enabled`
    - Username: `void`
    - Password: (Generated by my password manager)
15. Still in Bazarr, on the left sidebar, I selected `Radarr`, checked `Enabled`, and set the following:
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
16. Still in Bazarr, on the left sidebar, I selected `Subtitles` and set `Languages Filter` to `English`. Under `Languages Profile`, I then clicked `Add New Profile` and set `Name` to `English` and `tag` to `english`. Then, under `Default Language Profiles For Newly Added Shows`, I checked both `Series` and `Movies` and set them to `English`. Then, on the left sidebar, I selected `Providers`, and under `Enabled Providers`, I clicked the plus icon.

## Cup setup

1. I ran `getent group docker | cut -d: -f3` to find the group ID for the Docker group (it was `987`) and added it as a target: `user: "1000:987"` in `/srv/compose.yaml`.
2. I restarted everything via `docker compose down && docker compose up -d`.
