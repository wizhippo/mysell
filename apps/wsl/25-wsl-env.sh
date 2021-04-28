#!/bin/sh

[ ! -z "$WSL_DISTRO_NAME" ] || exit 0;

HOST_NS_SEARCH_LIST=$(powershell.exe -Command '$list = (Get-DnsClient).ConnectionSpecificSuffix; [system.String]::Join(" ", $list)' | tr -d '\r' | xargs)
NS_SEARCH_LIST=$(cat /etc/resolv.conf | grep search | awk '{print $2; exit;}')

if [ "$HOST_NS_SEARCH_LIST" != "$NS_SEARCH_LIST" ]; then
    echo "resolv.conf search '$NS_SEARCH_LIST' -> '$HOST_NS_SEARCH_LIST'"
    sudo cat /etc/resolv.conf > /tmp/resolv.conf.new
    sudo sed -i '/^search/d' /tmp/resolv.conf.new
    if [ ! -z "$HOST_NS_SEARCH_LIST" ]; then
        sudo echo "search $HOST_NS_SEARCH_LIST" >> /tmp/resolv.conf.new
    fi
    sudo mv -f /tmp/resolv.conf.new /etc/resolv.conf
fi

HAS_CHANGE="no"

HOST_IP=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}')
if [ ! -z "HOST_IP" ] && [ "$HOST_IP" != "$WSL_HOST_IP" ]; then
    echo "WSL_HOST_IP '$WSL_HOST_IP' -> '$HOST_IP'"
    export WSL_HOST_IP=$HOST_IP
    HAS_CHANGE="yes"
fi

CLIENT_IP=$(ip -4 addr show eth0 | grep -Po 'inet \K[\d.]+')
if [ ! -z "CLIENT_IP" ] && [ "$CLIENT_IP" != "$WSL_CLIENT_IP" ]; then
    echo "WSL_CLIENT_IP '$WSL_CLIENT_IP' -> '$CLIENT_IP'"
    export WSL_CLIENT_IP=$CLIENT_IP
    HAS_CHANGE="yes"
fi

if [ "$HAS_CHANGE" != "no" ]; then
    # WSLg installed not needed
    if [ "$XDG_RUNTIME_DIR" != "/mnt/wslg/runtime-dir" ]; then
        echo "Updating WSL display env"
        export DISPLAY=$WSL_HOST_IP:0.0
        powershell.exe -File $HOME/.dotfiles/apps/wsl/wsl-x410.ps1 -HostIP $WSL_HOST_IP -ClientIP $WSL_CLIENT_IP
    fi
fi
