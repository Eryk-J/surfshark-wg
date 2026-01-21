# surfshark-wg
Author:  Eryk Jensen <jenseneryk@gmail.com>
Date:    January 21, 2026


A small Bash utility for generating and managing Surfshark WireGuard client
configurations using Surfshark’s public server metadata API.

This tool fetches live server information,lets you select a server interactively,
and generates a wg-quick compatible configuration directly to your /etc/wireguard/ directory.

It does NOT handle Surfshark account login or authentication. You must provide
your own WireGuard private key for Surfshark to accept the connection.

Dependencies:
  - curl
  - jq
  - wireguard-tools (wg, wg-quick)

Directory layout:
  Surfshark setup config import directory (user-facing):
    ~/.config/surfshark-wg/PlaceConfHere/

HOW TO GET STARTED:                       
  **YOU ONLY HAVE TO DO THIS ONCE**
  1. Run "./surfshark-wg.sh setup" it handles:
       - Generation of directories & key storage.
       - Validation and adoption of Private Keys.
       - Fetch the current Surfshark server list.
       - Clean up.
  2. You place your Surfshark WireGuard config file that has your Private Key
     inside into the import directory under ~/.config/surfshark-wg/PlaceConfHere/
     Alternatively, you can input the Private Key via copy+paste or manually via the setup process.
  2. Running "surfshark-wg setup" will:
       - Validate the imported file
       - Fetch the current Surfshark server list
       - Generate a WireGuard config for wg-quick
       - Write it to /etc/wireguard/surfshark-wg.conf
       - Remove the imported file after success
  3. You then use "surfshark-wg up" to choose and connect to the VPN.

Usage: ./surfshark-wg.sh <command>

Note: Connecting and Disconnecting to wireguard requires root privilege.

Commands:
  setup     Setup, reset, and renew private keys and first server list
  renew     Get fresh server list from Surfshark
  up        Connect to VPN from list of servers (wg-quick up)
  down      Disconnect from current VPN config (wg-quick down)
  status    Check status of user connection
  connect   Connect to VPN with previous config/server (wg-quick up) 
  list      Show available servers and their loads 
  switch    Switch from one wireguard config to another without connecting
  reset     Reset EVERYTHING.

Examples:
  ./surfshark-wg.sh up
  ./surfshark-wg.sh status
  ./surfshark-wg.sh setup


Notes:
  - Root privileges are required to write to /etc/wireguard and run wg-quick.
  - The Surfshark server metadata API is undocumented and may change without
    notice.
  - This tool does not modify firewall or nftables rules. Leak prevention or
    kill-switch behavior must be handled separately.
  - You must supply a valid Surfshark WireGuard private key.


License:
  MIT
