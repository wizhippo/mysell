# Docker for windows
if [ ! -z WSL_CLIENT_IP ]; then
    export XDEBUG_CONFIG="remote_host=$WSL_CLIENT_IP client_host=$WSL_CLIENT_IP"
    return 0
fi

# Docker native
ip -4 addr show docker0 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    export XDEBUG_CONFIG="remote_host=host.docker.internal client_host=host.docker.internal"
    return 0
fi
