# Cluster Bootstrap Anleitung

Dieses Dokument beschreibt die Schritte, um ein frisches k3s Cluster mit diesem Repository zu verbinden und alle erforderlichen Infrastrukturkomponenten zu installieren.

---

## k3s installieren

Auf dem Zielsystem:

```bash
curl -sfL https://get.k3s.io | sudo INSTALL_K3S_EXEC="server --disable traefik" sh -

Kubeconfig einrichten:
```bash
 
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config
kubectl config current-context
kubectl get nodes -o wide

##Flux installieren und mit GitHub Repository verbinden

Flux Command Line Interface installieren:
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
flux --version

```bash direkt und in der .bashrc anhängen 
export GITHUB_USER="development-martin-rein" #hier muss dein git nutzer name stehen stehen 
export GITHUB_TOKEN="DEIN_TOKEN_HIER"        #hier muss dein gittoken rein

Flux bootstrappen:
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=homeserver \
  --branch=main \
  --path=clusters/my-cluster \
  --personal

Status prüfen:
kubectl get pods -n flux-system
flux get kustomizations -A


## Gateway API CRDs installieren
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

Prüfen:
kubectl get crds | grep gateway.networking.k8s.io

##MetalLB installieren

MetalLB stellt für Services vom Typ LoadBalancer IP-Adressen im Heimnetz bereit.

Basisinstallation (Controller + Speaker + CRDs):
kubectl apply -f \
  https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml

Pods prüfen:
kubectl get pods -n metallb-system

Die eigentliche Konfiguration von MetalLB (IPAddressPool, L2Advertisement) liegt im Git Repository unter kustomize/infra/metallb/ und wird durch die Flux Kustomization cluster-infra automatisch angewendet.

##Secrets und Passwörter anlegen

Bestimmte Konfigurationen enthalten Passwörter oder andere Geheimnisse und dürfen nicht im Repository liegen.

Beispiele:

Nextcloud Administrator Passwort

Datenbank Zugangsdaten (falls verwendet)

Die Secrets werden mit kubectl angelegt. Beispiel:
kubectl create secret generic nextcloud-admin-secret \
  --from-literal=admin-user="DEIN_BENUTZER" \
  --from-literal=admin-password="DEIN_PASSWORT" \
  -n nextcloud-production

Die dazugehörigen Deployments referenzieren diese Secrets über envFrom oder env.

## Nötigen rechte vergeben
'''bash
kubectl create clusterrolebinding source-controller-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=flux-system:source-controller

kubectl create clusterrolebinding cert-manager-controller-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=cert-manager:cert-manager

kubectl create clusterrolebinding helm-controller-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=flux-system:helm-controller

kubectl create clusterrolebinding notification-controller-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=flux-system:notification-controller

kubectl create clusterrolebinding metrics-server-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:metrics-server

kubectl create clusterrolebinding metallb-speaker-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=metallb-system:metallb-speaker

##Überprüfen, ob alles läuft
flux get kustomizations -A

kubectl get pods -A

kubectl get gatewayclass
kubectl get gateway -A
kubectl get httproute -A

Nextcloud sollte erreichbar sein über:

nextcloud.staging.home.lan (Staging)

nextcloud.home.lan (Production)

Voraussetzung ist, dass die DNS Einträge im Heimnetz auf die LoadBalancer IP des Gateways zeigen, die MetalLB vergeben hat.

Cert-Manager:
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.9.1/cert-manager.crds.yaml

DNS ohne DNS SERVER lokal

Windows
C:\Windows\System32\drivers\etc\hosts

Eintrag hinzufügen:
192.168.178.240  nextcloud.home.lan
192.168.178.240  nextcloud.staging.home.lan

Linux / Mac
sudo nano /etc/hosts

Eintrag:
192.168.178.240 nextcloud.home.lan
192.168.178.240 nextcloud.staging.home.lan

## setzten von umgebungsvariablen 
### kopieren k3s.yaml 
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/configfile/k3s.yaml 
### setzten der rechte im configfile/k3s.yaml verzeichniss
sudo chown user:user k3s.yaml
sudo chmod 600 k3s.yaml
### setzten umgebungsvariable
sudo nano etc/environment 
#### eintragen
    KUBECONFIG="/home/-!-ersetzte hier userverzeichnissname-!-/.kube/configfile/k3s.yaml"

## aufsetzten eines pod reset scriptes nach eine neustart
reset-script siehe scripts/reset-cluster.sh

## aufsetzten eines reset-cluster.service
sudo nano /etc/systemd/system/reset-cluster.service

####inhalt
[Unit]
Description=Reset Kubernetes cluster pods after boot
After=network-online.target k3s.service
Wants=network-online.target k3s.service

[Service]
Type=oneshot
User=homeserver
Group=homeserver

# Verzögerung, damit Kubernetes vollständig läuft
#                      sekunden setzten hier zB 30 wann das script nach start des Servers ausgeführt werden soll. Wenn direkt bei start läuft der cluster nicht sauber an.       
ExecStartPre=/bin/sleep 30 

ExecStart=/home/homeserver/homeserver/docs/scripts/reset-cluster.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target

## Befehle zum Service
### Aktivieren
sudo systemctl enable reset-cluster.service
sudo systemctl start reset-cluster.service
### Status Prüfen
sudo systemctl status reset-cluster.service -l
journalctl -xeu reset-cluster.service
### Deaktivieren 
sudo systemctl disable reset-cluster.service
sudo systemctl stop reset-cluster.service
### Units im BetriebsSystem neuladen
sudo systemctl daemon-reload


### mariadb
Secretanlegen:

# Production
kubectl create secret generic nextcloud-mariadb \
  -n nextcloud-production \
  --from-literal=database=nextcloud \
  --from-literal=username=nextcloud \
  --from-literal=password='DEIN_STARKES_PASSWORT<--VERÄNDERN' \
  --from-literal=root-password='DEIN_ROOT_PASSWORT<--VERÄNDERN'

# Staging
kubectl create secret generic nextcloud-mariadb \
  -n nextcloud-staging \
  --from-literal=database=nextcloud_staging \
  --from-literal=username=nextcloud \
  --from-literal=password='DEIN_STAGING_PASSWORT<--VERÄNDERN' \
  --from-literal=root-password='DEIN_STAGING_ROOT_PASSWORT<--VERÄNDERN'

## Longhorn 
auf dem Host des Clusters open-iscsi installieren.
###Erklärung
open-iscsi ist ein Linux-Paket, das den iSCSI-Client bereitstellt.
Es enthält das Programm iscsiadm, das Longhorn benötigt, um Volumes auf deinem Host einzuhängen.

Longhorn funktioniert so:

Longhorn erzeugt verteilte Block-Volumes (über Longhorn-Manager).

Um ein Volume einem Pod bereitzustellen, muss der Knoten selbst das Volume einhängen.

Dafür verwendet Longhorn den iSCSI-Protokoll-Stack von Linux.
### Befehle
sudo apt update
sudo apt install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid
#### Longhorn neustarten:
kubectl rollout restart daemonset longhorn-manager -n longhorn-system
kubectl rollout restart deployment longhorn-driver-deployer -n longhorn-system

