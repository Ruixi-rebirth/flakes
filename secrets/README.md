# Secrets

`secrets.yaml` is encrypted with sops (age). The decryption key lives at
`/var/lib/sops-nix/keys.txt` on each host - that is the only thing placed by hand.

Edit a value (needs the age key readable by you):

```bash
export SOPS_AGE_KEY_FILE=/path/to/keys.txt   # or: export SOPS_AGE_KEY="$(sudo cat /var/lib/sops-nix/keys.txt)"
sops set secrets/secrets.yaml '["<name>"]' '"<value>"'
```

## sing-box (`system/network/sing-box`)

Only needs to be done once; the same values work on every machine.

| Secret key                    | Generate                                                           |
| ----------------------------- | ------------------------------------------------------------------ |
| `singbox_uuid`                | `nix shell nixpkgs#sing-box -c sing-box generate uuid`             |
| `singbox_reality_private_key` | `nix shell nixpkgs#sing-box -c sing-box generate reality-keypair`  |
| `singbox_hy2_password`        | `nix shell nixpkgs#sing-box -c sing-box generate rand --base64 16` |
| `singbox_hy2_cert`            | see below                                                          |
| `singbox_hy2_key`             | see below                                                          |

`reality-keypair` prints a `PrivateKey` and a `PublicKey`:

- put `PrivateKey` in `singbox_reality_private_key`
- put `PublicKey` in `realityPublicKey` at the top of `system/network/sing-box/default.nix`
  (it is public and not stored in sops)

### Hysteria 2 certificate

Self-signed; clients connect with `insecure=1`. Keeping the cert/key in sops means a new
machine needs no manual cert generation.

```bash
d=$(mktemp -d)
nix shell nixpkgs#openssl -c openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -nodes -keyout "$d/key.pem" -out "$d/cert.pem" -days 36500 -subj /CN=bing.com
sops set secrets/secrets.yaml '["singbox_hy2_cert"]' "$(jq -Rs . < "$d/cert.pem")"
sops set secrets/secrets.yaml '["singbox_hy2_key"]'  "$(jq -Rs . < "$d/key.pem")"
shred -u "$d/key.pem"; rm -rf "$d"
```

Changing any of these means re-importing the links from `sudo singbox-links` on the clients.
