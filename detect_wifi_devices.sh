#!/bin/bash

SUBNET="192.168.1.0/24"
ARP_FILE="/tmp/arp-scan-results.txt"
KNOWN_DEVICES="/home/tu_usuario/known_devices.txt"

sudo arp-scan --localnet > $ARP_FILE

cat $ARP_FILE | grep "192.168." | awk '{print $1, $2}' | sort | while read ip mac; do
    oui=$(echo $mac | cut -c1-8 | tr ':' '-')
    vendor=$(grep -i ^$oui /usr/share/arp-scan/ieee-oui.txt | head -n 1 | awk '{$1=""; print $0}' | sed 's/^ *//')
    echo "$ip $mac - ${vendor:-Desconocido}"
done > /tmp/current_devices.txt

if [ ! -f $KNOWN_DEVICES ]; then
    cp /tmp/current_devices.txt $KNOWN_DEVICES
fi

sort $KNOWN_DEVICES -o $KNOWN_DEVICES

NEW_DEVICES=$(comm -13 $KNOWN_DEVICES /tmp/current_devices.txt)

if [ ! -z "$NEW_DEVICES" ]; then
    echo "To: tu_correo@gmail.com" > /tmp/alert.txt
    echo "Subject: ⚠️ Nuevo Dispositivo en tu Red" >> /tmp/alert.txt
    echo "From: tuemail@gmail.com" >> /tmp/alert.txt
    echo "" >> /tmp/alert.txt
    echo "⚠️ Nuevos dispositivos detectados en la red:" >> /tmp/alert.txt
    echo "$NEW_DEVICES" >> /tmp/alert.txt
    echo "" >> /tmp/alert.txt
    echo "Revisa si reconoces estos dispositivos." >> /tmp/alert.txt

    /usr/sbin/sendmail -t < /tmp/alert.txt

    cat /tmp/current_devices.txt > $KNOWN_DEVICES
fi
