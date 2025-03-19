# 📡 Detector de Nuevos Dispositivos Wi-Fi con Raspberry Pi

📺 **[Ver Video en YouTube](https://youtu.be/IvHE9_NFi6M)**

Este proyecto explica cómo configurar desde cero una Raspberry Pi para escanear automáticamente la red Wi-Fi local y recibir una alerta por correo electrónico cada vez que un **nuevo dispositivo** se conecte a tu red.

---

## 🚀 Instalación y Configuración Paso a Paso

### 1️⃣ Actualizar el Sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### 2️⃣ Instalar Paquetes Necesarios

```bash
sudo apt install arp-scan nmap mailutils postfix rsyslog -y
sudo chmod 1777 /tmp/
```

### 2️⃣ Descargar y Preparar `ieee-oui.txt`
Este archivo permite que `arp-scan` identifique fabricantes por direcciones MAC:

```bash
sudo wget -O /usr/share/arp-scan/ieee-oui.txt https://standards-oui.ieee.org/oui/oui.txt
sudo chmod 777 /usr/share/arp-scan/ieee-oui.txt
```

Ejecuta como root para limpiarlo:

```bash
sudo su
sudo sed -i 's/   (hex)//g' /usr/share/arp-scan/ieee-oui.txt
sudo grep -E '^[0-9A-Fa-f]{2}[-:][0-9A-Fa-f]{2}[-:][0-9A-Fa-f]{2}' /usr/share/arp-scan/ieee-oui.txt > /usr/share/arp-scan/ieee-oui-clean.txt
sudo mv /usr/share/arp-scan/ieee-oui-clean.txt /usr/share/arp-scan/ieee-oui.txt
sudo chmod 644 /usr/share/arp-scan/ieee-oui.txt
sudo chown iot:iot /usr/share/arp-scan/ieee-oui.txt
sudo ln -sf /usr/share/arp-scan/ieee-oui.txt /etc/ieee-oui.txt
sudo ln -sf /usr/share/arp-scan/ieee-oui.txt /etc/arp-scan/ieee-oui.txt
```

---

## 📬 Configuración de Postfix (Correo)

### 🔹 Ejecuta la configuración:

```bash
sudo dpkg-reconfigure postfix
```

Selecciona:
- **Tipo:** Sitio de Internet
- **Nombre de dominio:** El nombre de tu Raspberry Pi (`hostname`.local)
- **Correo receptor:** tu dirección de correo
- **Entrega local:** NO (usarás solo envío externo)
- **Forzar síncronas:** No
- **Local networks:** Predeterminado
- **Mailbox size limit:** `0`
- **Protocolos de Internet:** ipv4

Edita el archivo `/etc/postfix/main.cf` y asegúrate de que tenga:

```conf
myhostname = tu_raspberry.local
myorigin = tu_raspberry.local
local_transport = error:local delivery disabled
mydestination =
relayhost = [smtp.gmail.com]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
inet_interfaces = loopback-only
inet_protocols = ipv4
mailbox_size_limit = 0
recipient_delimiter = +
```

### 🔹 Autenticación con Gmail:
Activa la **verificación en 2 pasos** en tu cuenta Gmail, genera una contraseña de aplicación y añádela:

```bash
sudo nano /etc/postfix/sasl_passwd
```

Añade:

```
[smtp.gmail.com]:587 tuemail@gmail.com:contraseña_de_aplicación
```

Luego:

```bash
sudo chmod 600 /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd
sudo systemctl restart postfix
```

Prueba con:
```bash
echo "Prueba de correo" | mail -s "Test Postfix" tu_correo@gmail.com
```

Si hay problemas:
```bash
tail -f /var/log/mail.log
```

---

## 🖥️ Script de Escaneo de Red

Crea el script `detect_wifi_devices.sh`:

```bash
sudo nano /home/iot/detect_wifi_devices.sh
```

Añade esto:

```bash
#!/bin/bash

SUBNET="10.0.0.0/24"
ARP_FILE="/tmp/arp-scan-results.txt"
KNOWN_DEVICES="/home/iot/known_devices.txt"

sudo arp-scan --localnet > $ARP_FILE

cat $ARP_FILE | grep "10.0.0." | awk '{print $1, $2}' | sort | while read ip mac; do
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
```

Dale permisos de ejecución:
```bash
sudo chmod +x /home/iot/detect_wifi_devices.sh
```

Ejecuta para probar:
```bash
/home/iot/detect_wifi_devices.sh
```

---

## 🕒 Automatizar con Cron
Abre el cron:
```bash
crontab -e
```

Añade esta línea (cada 5 minutos):

```bash
*/5 * * * * /home/iot/detect_wifi_devices.sh >> /var/log/detect_wifi.log 2>&1
```

Guarda y revisa:
```bash
crontab -l
```

---

## 📝 Comprobar Logs
Revisa que todo funcione correctamente:

```bash
tail -f /var/log/detect_wifi.log
tail -f /var/log/mail.log
```

---

## 📄 Licencia

Este proyecto está bajo la licencia **MIT**. Eres libre de utilizar, modificar y distribuir este software según sus términos. Para más información, revisa el archivo [LICENSE](LICENSE).

---

📌 **Contacto y más información:**
- [🌐 Visita mi web](https://davidcanoteayuda.com)
- [📲 Únete a mi Telegram](https://t.me/davidcanoteayuda_oficial)
- [🤖 Conéctate en Discord](https://discord.com)
- 🎥 [Descubre más en mi canal de YouTube](https://www.youtube.com)  

---

¡Gracias por usar mi proyecto! ⭐

