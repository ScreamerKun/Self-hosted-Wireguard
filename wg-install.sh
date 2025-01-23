#!/bin/bash

# Проверка, выполнен ли скрипт от имени root
if [ "$(id -u)" -ne 0 ]; then
   echo "Этот скрипт должен быть выполнен от имени root" 
   exit 1
fi

# Обновление списков пакетов и установка Wireguard
apt update
apt install -y wireguard

# Определение системы и выполнение соответствующих действий
if pidof systemd > /dev/null; then
    echo "Detected systemd. Configuring systemd services..."

    # Создание systemd файлов
    cd /etc/systemd/system/
    cat << EOF > wgui.service
[Unit]
Description=Restart WireGuard
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl restart wg-quick@wg0.service

[Install]
RequiredBy=wgui.path
EOF

    cat << EOF > wgui.path
[Unit]
Description=Watch /etc/wireguard/wg0.conf for changes

[Path]
PathModified=/etc/wireguard/wg0.conf

[Install]
WantedBy=multi-user.target
EOF

    # Применение systemd конфигураций
    systemctl enable wgui.{path,service}
    systemctl start wgui.{path,service}

elif command -v openrc >/dev/null 2>&1; then
    echo "Detected OpenRC. Configuring OpenRC scripts..."

    # Установка inotify-tools, если это OpenRC
    if ! command -v inotifyd >/dev/null; then
        echo "Installing inotify-tools..."
        apt install -y inotify-tools
    fi

    # Создание openrc файлов
    cd /usr/local/bin/
    cat << EOF > wgui
#!/bin/sh
wg-quick down wg0
wg-quick up wg0
EOF
    chmod +x wgui

    cd /etc/init.d/
    cat << EOF > wgui
#!/sbin/openrc-run

command=/sbin/inotifyd
command_args="/usr/local/bin/wgui /etc/wireguard/wg0.conf:w"
pidfile=/run/\${RC_SVCNAME}.pid
command_background=yes
EOF
    chmod +x wgui

    # Применение openrc конфигураций
    rc-service wgui start
    rc-update add wgui default

else
    echo "Не найдены поддерживаемые init-системы (systemd или openrc)." 
    exit 1
fi

echo "Настройка WireGuard завершена."
