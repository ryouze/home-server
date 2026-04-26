# NAS

I want to use my external 2 TB HDD (connected over USB) for Jellyfin and as a NAS over Samba.

## Mount

I need to mount the HDD first and do so automatically at boot.

1. I plugged in my external 2 TB HDD over USB. It was already formatted as `ext4` and contained my old files.
2. I used `lsblk -f` to view available devices with UUIDs.
3. I created a mount point for the HDD: `sudo mkdir -p /srv/storage`.
4. I backed up `/etc/fstab` via `sudo cp /etc/fstab /etc/fstab.bak` and then opened it via `sudo nano /etc/fstab`.
5. I added the following at the end: `UUID=HDD_UUID_HERE /srv/storage ext4 defaults,nofail 0 2`.
6. I mounted the disk using `sudo mount -a` and then ran `sudo systemctl daemon-reload`.
7. I confirmed that it was mounted by using `df -h /srv/storage` and `ls -ld /srv/storage`.

## File layout

I need to organize all files by directory, as my old layout was pretty bad.

1. I created the following flat layout (`/srv/storage` is the raw HDD, `/srv/storage/data` is the actual "working directory"):
    ```sh
    /srv
    `-- storage
        `-- data
            |-- dev
            |-- games
            |-- misc
            |-- movies
            |-- temp
            `-- tv
    ```
2. I set file permissions to only allow access for my user (`void`):
    ```sh
    sudo chown -R void:void /srv
    find /srv/storage/data -type d -exec chmod 700 {} +
    find /srv/storage/data -type f -exec chmod 600 {} +
    ```

## Disk health

I need some way to tell when my disks are about to fail.

1. I installed Smartmontools with `sudo apt install smartmontools` and enabled it with `sudo systemctl enable --now smartmontools`.
2. I ran the following to view the logs:
    ```sh
    sudo systemctl status smartmontools
    sudo journalctl -u smartmontools -n 50 --no-pager
    ```

## Samba

I need to be able to access the files using Finder on my MacBook.

1. I installed Samba with `sudo apt install samba`.
2. I backed up `/etc/samba/smb.conf` via `sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.bak`.
3. I opened it via `sudo nano /etc/samba/smb.conf` and replaced it with `configs/smb.conf`.
4. I checked the config for mistakes using `sudo testparm -s`.
5. I added a new password from my password manager (this will be required in Finder on macOS): `sudo smbpasswd -a void`.
6. I started the Samba service via `sudo systemctl enable --now smbd` and restarted it via `sudo systemctl restart smbd`.
7. I enabled the Samba whitelist: `sudo ufw allow Samba`.
8. I installed `smbclient` via `sudo apt install smbclient` and tested if it worked with `smbclient -L //localhost -U void`, then uninstalled it via `sudo apt purge smbclient`.
9. In macOS Finder, I selected `Network` -> `DEBIAN` and entered my username and password from my password manager. I also connected to `smb://debian.local` on my iPhone.
