#!/bin/bash

# Проверка, выполнен ли скрипт от имени root
if [ "$(id -u)" -ne 0 ]; then
   echo "Этот скрипт должен быть выполнен от имени root" 
   exit 1
fi

# Определяем дистрибутив и устанавливаем WireGuard в соответствии с официальной документацией
if [ -f /etc/os-release ]; then
    . /etc/os-release

    case "$ID" in
        "debian"|"ubuntu")
            apt-get update
            apt-get install -y gnupg
            echo "deb http://deb.debian.org/debian $(lsb_release -cs)-backports main" > /etc/apt/sources.list.d/backports.list
            apt-get update
            apt-get install -y wireguard
            ;;
        "centos"|"rhel")
            yum install -y epel-release elrepo-release
            yum install -y kmod-wireguard wireguard-tools
            ;;
        "fedora")
            dnf install -y wireguard-tools
            ;;
        "arch")
            pacman -Syu --noconfirm wireguard-tools
            ;;
        *)
            echo "Дистрибутив Linux не поддерживается этим скриптом."
            exit 1
            ;;
    esac
else
    echo "Файл /etc/os-release не найден. Невозможно определить дистрибутив."
    exit 1
fi

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
        install_package inotify-tools
    fi

    # Создание OpenRC файлов
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

    # Применение OpenRC конфигураций
    rc-service wgui start
    rc-update add wgui default

else
    echo "Не найдены поддерживаемые init-системы (systemd или openrc)." 
    exit 1
fi

echo "Настройка WireGuard завершена."
