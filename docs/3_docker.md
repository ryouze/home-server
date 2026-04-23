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
    |-- caddy
    |   |-- conf
    |   |   `-- Caddyfile
    |   |-- config
    |   `-- data
    |-- compose.yaml
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
2. I set the owner to my user instead of root:
    ```sh
    sudo chown -R void:void /srv/compose.yaml /srv/caddy /srv/jellyfin /srv/qbittorrent
    ```

## Docker Compose setup

I need to put all of my services in the `compose.yaml` file.

1. I set `/srv/compose.yaml` to `configs/compose.yaml` via `nano`. I omitted the `Caddy` setup on 1st run so the `8096:8096/tcp` port mapping needs to be added to the `srv/compose.yaml` for Jellyfin and `8080:8080` for qBittorrent.
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
5. I selected the preferred metadata language to `English` and the region to the `United States`.
6. I left `Allow remote connections to this server` enabled.
7. After the main page loaded, I clicked the profile icon in the top right corner and clicked `Dashboard` (Administration).
8. I opened the `General` tab and set `Enable QuickConnect on this server` to `False`.
9. I opened the `Branding` tab, set `Enable the splash screen image` to enabled, and entered custom CSS code from this repository: https://github.com/loof2736/scyfin
10. I opened `Users` and created non-root user accounts, disabling `Hide this user from login screens`.
11. I opened the `Playback` -> `Transcoding` tab and set Hardware Acceleration to `Intel Quicksync (QSV)`. I then ran `docker exec -it jellyfin /usr/lib/jellyfin-ffmpeg/vainfo` to retrieve supported codecs, and under `Enable hardware decoding for`, I checked everything except `AV1`, `HEVC RExt 8/10bit`, and `HEVC RExt 12bit`. Refer to docs: https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel#configure-with-linux-virtualization
12. I verified that the hardware acceleration is working correctly, as described here: https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel#verify-on-linux

## Caddy setup

1. I set `/srv/caddy/conf/Caddyfile` to `configs/Caddyfile` via `nano`.
2. I re-added `caddy` container to `/srv/compose.yaml`, this time without the the port mapping for Jellyfin and qBittorrent.
3. In the Jellyfin `Dashboard` (Administration) (see `##Jellyfin-setup`), I opened the `Networking` tab and set the `Base URL` to `/jellyfin` and clicked `Save` at the bottom.
4. I ran `docker compose down` and `docker compose up -d` for a clean restart.
5. In the Jellyfin `Dashboard` (Administration) (see `##Jellyfin-setup`), I opened the `Networking` tab and set the `Known Proxies` to the output of `docker network inspect srv_default --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'` (e.g., `123.12.0.3`). When traffic passes through a reverse proxy, Jellyfin will otherwise see the proxy's IP instead of the client's IP.
