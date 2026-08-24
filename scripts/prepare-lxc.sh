#!/usr/bin/env bash
# Deja los contenedores LXC en condiciones de correr k3s.
#
# Se ejecuta EN EL ANFITRION Proxmox, despues del terraform apply y antes de
# instalar k3s. Es idempotente.
#
# Uso:  ./prepare-lxc.sh 201 202 203
#
# Que hace y por que:
#   apparmor unconfined  -> el perfil por defecto bloquea el montaje de cgroups
#   cgroup2.devices.allow -> containerd necesita crear dispositivos
#   cap.drop vacio        -> k3s pide capacidades que LXC quita por defecto
#   mount.auto proc y sys -> kubelet lee y escribe en ambos
#   /dev/kmsg             -> k3s aborta si no existe, y en LXC no hay. Se apunta
#                            a /dev/console, que es el apaño estandar
#   modulos del anfitrion -> overlay y br_netfilter los usa el contenedor pero
#                            se cargan fuera, porque el kernel es compartido
set -euo pipefail

[ $# -ge 1 ] || { echo "Uso: $0 <vmid> [vmid...]"; exit 1; }

echo ">>> modulos del kernel en el anfitrion"
for m in overlay br_netfilter; do
  modprobe "$m" 2>/dev/null || true
  grep -qxF "$m" /etc/modules-load.d/k3s.conf 2>/dev/null || echo "$m" >> /etc/modules-load.d/k3s.conf
done

for CTID in "$@"; do
  CONF="/etc/pve/lxc/${CTID}.conf"
  [ -f "$CONF" ] || { echo "!! no existe $CONF, salto"; continue; }

  echo ">>> preparando contenedor $CTID"
  # Limpia lineas previas para poder reejecutar sin duplicar
  sed -i '/^lxc\.apparmor\.profile/d;/^lxc\.cgroup2\.devices\.allow/d;/^lxc\.cap\.drop/d;/^lxc\.mount\.auto/d' "$CONF"
  cat >> "$CONF" <<'LXCCONF'
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.mount.auto: proc:rw sys:rw
LXCCONF

  # El contenedor tiene que estar arrancado para poder tocarlo por dentro
  pct status "$CTID" | grep -q running || pct start "$CTID"
  sleep 3

  # /dev/kmsg dentro del contenedor, ahora y en cada arranque
  pct exec "$CTID" -- bash -c '
    ln -sf /dev/console /dev/kmsg
    cat > /etc/systemd/system/kmsg-link.service <<EOF
[Unit]
Description=Enlaza /dev/kmsg a /dev/console para k3s en LXC
DefaultDependencies=no
Before=k3s.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/ln -sf /dev/console /dev/kmsg

[Install]
WantedBy=sysinit.target
EOF
    systemctl daemon-reload
    systemctl enable kmsg-link.service >/dev/null 2>&1
  '
  echo "   $CTID listo"
done

echo ">>> reiniciando contenedores para aplicar la configuracion"
for CTID in "$@"; do pct reboot "$CTID" || true; done
echo "Hecho. Espera a que respondan por SSH y lanza la instalacion de k3s."
