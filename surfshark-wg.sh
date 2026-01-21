#!/usr/bin/env bash
#
# surfshark-wg.sh: surfshark-wg written in Bash
#
# Author:  Eryk Jensen <jenseneryk@gmail.com>
# Date:    January 16, 2026
# License: MIT

set -e

#Config startup & argument help

main() {	
	app="surfshark-wg"
	
	data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/$app"
	cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/$app"
	config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/$app"
	wg_config="/etc/wireguard/$app.conf"
	shopt -s nullglob
	key_loc=("$config_dir/PlaceConfHere"/*.conf)
	shopt -u nullglob
	config_file="$data_dir/pks"
	grab_config="$config_dir/PlaceConfHere/"

	# Variables 
	apidomain='https://api.surfshark.com/'
	server_url="$apidomain/v4/server/clusters/"
	server_file="$cache_dir/serverlist.cache"
	dns_servers=("162.252.172.57" "149.154.159.92")

	mkdir -p "$data_dir" "$cache_dir" "$config_dir" "$grab_config" 

reset_all=0
check_status=0
wireguard_down=0
wireguard_up=0
wireguard_connect=0
renew_servers=0
priv_key=0
switch_conf=0
print_servers=0

parse_arg "$@"
}

parse_arg() {
  local arg="${1:-}"

  case "$arg" in
    up) wireguard_up=1 ;;
    down) wireguard_down=1 ;;
    connect) wireguard_connect=1 ;;
    status) check_status=1 ;;
    reset) reset_all=1 ;;
    setup) priv_key=1 ;;
    switch) switch_conf=1 ;;
    list) print_servers=1 ;;
    renew) renew_servers=1 ;;
    ""|help|-h|--help) usage; exit 0 ;;
    *) usage; echo >&2; echo "Unknown command: $arg and $key_loc" >&2 ; exit 1 ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: ./surfshark-wg.sh <command>

Note: Connecting and Disconnecting to wireguard requires root privilege.

Commands:
  setup     Setup, reset, and renew private keys
  reset     Reset EVERYTHING.
  renew     Get fresh server list from Surfshark
  up        Connect to VPN from list of servers (wg-quick up)
  down      Disconnect from current VPN config (wg-quick down)
  status    Check status of user connection
  connect   Connect to VPN with previous config/server (wg-quick up) 
  list      Show available servers and their loads 
  switch    Switch from one wireguard config to another without connecting.

Examples:
  ./surfshark-wg.sh up
  ./surfshark-wg.sh status
  ./surfshark-wg.sh setup
EOF
}

reset_it() {
	echo "You need to run this as a super user for everything to be reset"
	read -rp $'THIS WILL RESET EVERYTHING TO DEFAULT! Type YES (all caps) to continue.\nTyping anything else will abort: ' reset_ans
	if [[ $reset_ans == "YES" ]]; then
	sudo wg-quick down "$app" >/dev/null 2>&1 || true
	rm -rf "$config_dir" "$data_dir" "$cache_dir" "$wg_config" || true
	rm -rf "$grab_config" && mkdir "$grab_config" || true
	echo "Run setup/renew commands to begin using surfshark-wg again."
	exit 0
	else
		exit 1
	fi
}


#Parsed argument functions
user_status() {
local current_status=$(curl -sS --connect-timeout 5 "$apidomain/v1/server/user")
if [ "$(jq -r '.secured' <<<"$current_status")" == "true" ]; then 
jq ' "You ARE connected to \(.ip), \(.city), \(.country)" '<<<"$current_status"; else
echo "You ARE NOT currently connected to the VPN!"
# jq ' "You ARE NOT connected to Surfshark VPN at \(.ip), \(.city), \(.country)" '<<<"$current_status"
exit 1
fi
}

get_servers() {
	if [ -f $server_file ]; then mv "$server_file" "$server_file.old"; fi
	curl -fsSL --connect-timeout 5 "$server_url" -o "$server_file.tmp" && mv "$server_file.tmp" "$server_file"
		if [ -f "$server_file" ]; then
		rm -f "$server_file.old"
		echo "New server list downloaded and formatted."; else
		mv "$server_file.old" "$server_file"
		echo "Unable to download server information, previous server file will be used."
                exit 2
		fi
}

key_fromfile() {
	if (( ${#key_loc[@]} >= 1 )); then
		:
	else
echo "Place your surfshark .conf file in the ~/.config/surfshark-wg/PlaceConfHere directory." >&2
echo "This file will be deleted once the key is extracted!" >&2
exit 1
	fi

cp "$key_loc" "$key_loc".temp

while IFS= read -r line; do
	if [[ $line =~ ^PrivateKey[[:space:]]*=[[:space:]]*([A-Za-z0-9+/=]{44})$ ]]; then
	private_key="${BASH_REMATCH[1]}"
	break
fi

done < "$key_loc".temp

if [[ -z $private_key ]]; then
	echo "The file in '~/.config/surfshark-wg/PlaceConfHere' does not contain a valid private key. Make sure you are using a WireGuard configuration file from Surfshark." >&2
rm -f "$key_loc".temp
exit 1
fi

rm -f "$key_loc".temp


create_key && [[ -f $key_loc ]] && rm -f "$key_loc"
}

private_keygen() {
read -rsp "Paste or type your Surfshark WireGuard private key: " private_key
echo

if [[ -z $private_key ]]; then 
  echo "Private key missing" >&2
  exit 1
fi

if [[ $private_key =~ ^[A-Za-z0-9+/=]{44}$ ]]; then
	create_key; else
  echo "Private key appears invalid" >&2
  exit 1
fi
}

create_key() {

old_umask=$(umask)

umask 077
printf "$private_key" > "$config_file"
umask "$old_umask"
echo "A new Private Key has been successfully adopted."
return 0
}


key_setup() {
if [[ -f $config_file ]]; then
	read -rp $'YOU ALREADY HAVE A PRIVATE KEY SAVED! Type YES (all caps) to overwrite it.\nTyping anything else will abort: ' secure_ans
	if [[ $secure_ans =~ ^YES$ ]]; then
		:
	else
		exit 1
	fi
else 
echo "Welcome to surfshark-wg created by Eryk Jensen, please read the README. ENJOY!"
fi

read -rp "Are you using a Surfshark config file? (y/n): " ans
if [[ $ans =~ ^[Yy]$ ]]; then
	key_fromfile
elif [[ $ans =~ ^[Nn]$ ]]; then
	read -rp "Do you want to paste your private key manually? (y/n): " ans
if [[ $ans =~ ^[Yy]$ ]]; then
    private_keygen
elif [[ $ans =~ ^[Nn]$ ]]; then
    echo "Cannot continue without a private key." >&2
    exit 1
else
    echo "Please answer y or n." >&2
    exit 1
fi

else
  echo "Please answer y or n." >&2
  exit 1
fi
}

parse_json() {
if [ ! -f $server_file ]; then echo "No server file detected. Run the renew command before listing available servers."; exit 1; fi
jq -r '
  to_entries[]
  | "\(.key)) \(.value.country)-\(.value.location)|\(.value.load)| \(.value.tags)"
' "$server_file" \
| paste -d $'\t' - - - \
| column -t -s $'\t'
}

select_server() {
read -rp "Enter the server number you would like to connect to:" srvnum
{
read -r endpoint
read -r pub_key
} < <(
jq ".[$srvnum]
| .connectionName, .pubKey
" $server_file
)

pub_key=${pub_key#\"}; pub_key=${pub_key%\"}
endpoint=${endpoint#\"}; endpoint=${endpoint%\"}

template_conf="[Interface]\nAddress = 10.14.0.2/16\nPrivateKey = $(<"$config_file")\nDNS = ${dns_servers[0]}, ${dns_servers[1]}\n[Peer]\nPublicKey = $pub_key\nAllowedIPs = 0.0.0.0/0\nEndpoint = $endpoint:51820"

tmp=$(mktemp)
printf '%b' "$template_conf" > "$tmp" && sudo mv "$tmp" $wg_config
}

wg_confirmdown() {
read -rp "Disconnect from VPN connection? [Y/n]:" conans
	if [[ $conans =~ ^[Yy]$ ]]; then
	wg_down
	else
	echo "Disconnection Aborted."
	exit 1
fi
}

wg_down() {
if ip link show $app >/dev/null 2>&1; then
sudo wg-quick down $app >/dev/null 2>&1 && echo "Disconnected from VPN."; else
echo "You are not currently connected to this VPN."
fi
}

wg_up() {
if ip link show $app >/dev/null 2>&1; then
sudo wg-quick down $app >/dev/null 2>&1
fi
sudo wg-quick up $app >/dev/null 2>&1 && echo "Successfully connected to VPN..." && user_status || echo "Unable to connect to Surfshark VPN; make sure you have chosen a configuration file. (-s)" >&2
}

setup_check() {
if [ ! -f $config_file ]; then
	echo "No setup file detected. Please read the README and run the setup command!"; else
	return 0
fi
}

#Script start

main "$@"

if [ $reset_all -eq 1 ]; then reset_it; exit 1; fi

if [ $wireguard_up -eq 1 ]; then setup_check; parse_json; select_server; wg_up; fi

if [ $wireguard_connect -eq 1 ]; then setup_check; wg_up; exit 1; fi

if [ $wireguard_down -eq 1 ]; then wg_confirmdown; exit 1; fi

if [ $switch_conf -eq 1 ]; then parse_json; select_server; fi

if [ $print_servers -eq 1 ]; then parse_json; exit 1; fi

if [ $check_status -eq 1 ]; then user_status; exit 1; fi

if [ $renew_servers -eq 1 ]; then get_servers; exit 1; fi

if [ $priv_key -eq 1 ]; then key_setup; exit 1; fi
