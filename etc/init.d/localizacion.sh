#! /bin/bash
### BEGIN INIT INFO
# Provides:          localizacion
# Required-Start:    $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: servicio de localizacion y reportes
# Description:       inicia el servicio de localizacion y los reportes
### END INIT INFO


ipwan=`ifconfig | grep -o wwan0`
while [ "$ipwan" != wwan0 ]
do
	ipwan=`ifconfig | grep -o wwan0`
done


ifconfig eth0 down
ifconfig wlan0 down

cd /etc/openvpn/
openvpn --config ClientVPN.ovpn > /dev/null &
sleep 15
ifconfig
ipvpn=`ifconfig | grep -o tun0`
while [ "$ipvpn" != tun0 ]
do
        killall openvpn
        cd /etc/openvpn/
        openvpn --config ClientVPN.ovpn > /dev/null &
        sleep 15
        ipvpn=`ifconfig | grep -o tun0`
done
sleep 6
printf "%s" "ESPERANDO AL SERVIDOR ..."
while ! ping -c 1 -n -w 2 10.10.10.1&> /dev/null
do
    printf "%c" "."
done
printf "\n%s\n"  "EL SERVIDOR ESTÁ online"

printf "ESPERANDO AL GPS"
#ipgps=`gpspipe -r -n 15 | grep -n 'GNGGA' -m 1 | cut -d "," -f 7`

while [ `gpspipe -r -n 15 | grep -n 'GNGGA' -m 1 | cut -d , -f 7` -lt 1 ]
do
        printf "\n gps inactivo"
#       ipgps=`gpspipe -r -n 15 | grep -n GNGGA -m 1 | cut -d , -f 7`
done

printf "\n gps activo"
cd  /home/pi/tralnx
./tralnxd > /dev/null &
printf  "\n cliente  traccar lanzado\n"

cd /home/pi/
./reporte
printf "\nSERVICIO DE REPORTES ARRANCADO\n"

