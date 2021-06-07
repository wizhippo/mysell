#!/bin/sh

[ ! -z "$WSL_DISTRO_NAME" ] || exit 0

export WINHOME=$(wslpath "$(wslvar USERPROFILE)")
export WIN_GPG_AGENT_HOME="${WINHOME}/.local/opt/win-gpg-agent"

HOST_NS_SEARCH_LIST=$(powershell.exe -Command '$list = (Get-DnsClient).ConnectionSpecificSuffix; [system.String]::Join(" ", $list)' | tr -d '\r' | xargs)
NS_SEARCH_LIST=$(cat /etc/resolv.conf | grep search | awk '{print $2; exit;}')

if [ "$HOST_NS_SEARCH_LIST" != "$NS_SEARCH_LIST" ]; then
    echo "resolv.conf search '$NS_SEARCH_LIST' -> '$HOST_NS_SEARCH_LIST'"
    sudo cat /etc/resolv.conf >/tmp/resolv.conf.new
    sudo sed -i '/^search/d' /tmp/resolv.conf.new
    if [ ! -z "$HOST_NS_SEARCH_LIST" ]; then
        sudo echo "search $HOST_NS_SEARCH_LIST" >>/tmp/resolv.conf.new
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

if [ -d "$WIN_GPG_AGENT_HOME" ]; then
    # https://github.com/rupor-github/win-gpg-agent
    # win-gpg-agent should be running first from windows

    # detect what we have
    if [ $(uname -a | grep -c "Microsoft") -eq 1 ]; then
        export ISWSL=1 # WSL 1
    elif [ $(uname -a | grep -c "microsoft") -eq 1 ]; then
        export ISWSL=2 # WSL 2
    else
        export ISWSL=0
    fi

    if [ ${ISWSL} -eq 1 ]; then
        # WSL 1 could use AF_UNIX sockets from Windows side directly
        if [ -n ${WSL_AGENT_HOME} ]; then
            export GNUPGHOME=${WSL_AGENT_HOME}
            export SSH_AUTH_SOCK=${WSL_AGENT_HOME}/S.gpg-agent.ssh
        fi
    elif [ ${ISWSL} -eq 2 ]; then
        # WSL 2 require socat to create socket on Linux side and sorelay on the Windows side to interop
        if [ ! -d ${HOME}/.gnupg ]; then
            mkdir ${HOME}/.gnupg
            chmod 0700 ${HOME}/.gnupg
        fi
        if [ -n ${WIN_GNUPG_HOME} ]; then
            # setup gpg-agent socket
            _sock_name=${HOME}/.gnupg/S.gpg-agent
            ss -a | grep -q ${_sock_name}
            if [ $? -ne 0 ]; then
                rm -f ${_sock_name}
                (setsid socat UNIX-LISTEN:${_sock_name},fork EXEC:"${WIN_GPG_AGENT_HOME}/sorelay.exe -a ${WIN_GNUPG_HOME//\:/\\:}/S.gpg-agent",nofork &) >/dev/null 2>&1
            fi
            # setup gpg-agent.extra socket
            _sock_name=${HOME}/.gnupg/S.gpg-agent.extra
            ss -a | grep -q ${_sock_name}
            if [ $? -ne 0 ]; then
                rm -f ${_sock_name}
                (setsid socat UNIX-LISTEN:${_sock_name},fork EXEC:"${WIN_GPG_AGENT_HOME}/sorelay.exe -a ${WIN_GNUPG_HOME//\:/\\:}/S.gpg-agent.extra",nofork &) >/dev/null 2>&1
            fi
            unset _sock_name
        fi
        if [ -n ${WIN_AGENT_HOME} ]; then
            # and ssh-agent socket
            export SSH_AUTH_SOCK=${HOME}/.gnupg/S.gpg-agent.ssh
            ss -a | grep -q ${SSH_AUTH_SOCK}
            if [ $? -ne 0 ]; then
                rm -f ${SSH_AUTH_SOCK}
                (setsid socat UNIX-LISTEN:${SSH_AUTH_SOCK},fork EXEC:"${WIN_GPG_AGENT_HOME}/sorelay.exe ${WIN_AGENT_HOME//\:/\\:}/S.gpg-agent.ssh",nofork &) >/dev/null 2>&1
            fi
        fi
    else
        echo "Unkonwn WSL version"
    fi
fi
