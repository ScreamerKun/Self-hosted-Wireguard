Сначала устанавливаем Wireguard через скрипт и создаем необходимые службы для работы в GUI
1. chmod +x wg-install.sh
2. ./wg-install.sh

После запускаем сборку docker-compose, получаем доступ к GUI по 5000 порту.   
3. docker-compose up -d
