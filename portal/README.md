# officelab — `portal` VM deploy glue

Host/deploy configuration for the **Academic Performance Portal** instance on the
`portal` VM (ohmbox / Proxmox, internal bridge vmbr1, 10.10.10.70). The application
code lives in the separate **academic-performance-portal** repo, cloned at `/opt/portal`;
this repo only holds glue that shouldn't live in the app repo.

## portal.service
systemd unit that runs the built Next.js app (`next start`) as `portaladmin`, bound to
`0.0.0.0:3000` on vmbr1 so Caddy on the **webapps** VM can reverse-proxy to it. It reads
`/opt/portal/.env` (loaded automatically by Next).

Install / update on the portal VM:

    sudo cp portal/portal.service /etc/systemd/system/portal.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now portal.service
    systemctl status portal.service
    
Prerequisites: app built (`npm ci && npm run build` in `/opt/portal`) and
`/opt/portal/.env` present (mode 600, owned by `portaladmin`).

## Bring-up after an ohmbox reboot
The VM disk is on an encrypted ZFS dataset with `onboot=0`, so after a host reboot:

    # on the ohmbox host:
    zfs load-key rpool/secure/portal && qm start <vmid>
    # portal.service then starts automatically (it's enabled)
