# Cluster Bootstrap Anleitung

Dieses Dokument beschreibt die Schritte, um ein frisches k3s Cluster mit diesem Repository zu verbinden und alle erforderlichen Infrastrukturkomponenten zu installieren.

---

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)  
- [k3s installieren](#k3s-installieren)  
- [Kubeconfig einrichten](#kubeconfig-einrichten)  
- [Flux installieren und Repository bootstrappen](#flux-installieren-und-repository-bootstrappen)  
- [Gateway Application Programming Interface Custom Resource Definitions installieren](#gateway-application-programming-interface-custom-resource-definitions-installieren)  
- [MetalLB installieren](#metallb-installieren)  
- [Secrets und Passwörter anlegen](#secrets-und-passwörter-anlegen)  
  - [Nextcloud Administrator Secret](#nextcloud-administrator-secret)  
  - [MariaDB Secrets](#mariadb-secrets)  
- [Notwendige Rechte vergeben](#notwendige-rechte-vergeben)  
- [Cert-Manager Custom Resource Definitions installieren](#cert-manager-custom-resource-definitions-installieren)  
- [Domainnamen ohne lokalen Domain Name System Server](#domainnamen-ohne-lokalen-domain-name-system-server)  
- [KUBECONFIG dauerhaft setzen](#kubeconfig-dauerhaft-setzen)  
- [Pod Reset nach Neustart automatisieren](#pod-reset-nach-neustart-automatisieren)  
- [Longhorn Host Voraussetzungen](#longhorn-host-voraussetzungen)  
- [Gesamtstatus prüfen](#gesamtstatus-prüfen)  
- [Nextcloud Erreichbarkeit](#nextcloud-erreichbarkeit)  

---

## Voraussetzungen

- Linux Zielsystem für den k3s Server  
- Netzwerkzugriff auf GitHub  
- GitHub Personal Access Token mit Zugriff auf das Repository  
- Dieses Repository ist erreichbar (GitHub) und Flux darf darauf zugreifen  

---

## k3s installieren

k3s installieren und Traefik deaktivieren:

`curl -sfL https://get.k3s.io | sudo INSTALL_K3S_EXEC="server --disable traefik" sh -`

---

## Kubeconfig einrichten

Kubeconfig ins Benutzerverzeichnis kopieren und Rechte setzen:

`mkdir -p ~/.kube`  
`sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config`  
`sudo chown "$USER:$USER" ~/.kube/config`  
`chmod 600 ~/.kube/config`

Prüfen:

`kubectl config current-context`  
`kubectl get nodes -o wide`

---

## Flux installieren und Repository bootstrappen

### Flux Command Line Interface installieren

`curl -s https://fluxcd.io/install.sh | sudo bash`  
`flux --version`

### Umgebungsvariablen setzen

Für die aktuelle Sitzung:

`export GITHUB_USER="development-martin-rein"`  
`export GITHUB_TOKEN="DEIN_TOKEN_HIER"`

Optional dauerhaft in der Shell Konfiguration speichern:

`echo 'export GITHUB_USER="development-martin-rein"' >> ~/.bashrc`  
`echo 'export GITHUB_TOKEN="DEIN_TOKEN_HIER"' >> ~/.bashrc`  
`source ~/.bashrc`

### Flux bootstrappen

`flux bootstrap github \`  
`  --owner="$GITHUB_USER" \`  
`  --repository="homeserver" \`  
`  --branch="main" \`  
`  --path="clusters/my-cluster" \`  
`  --personal`

Status prüfen:

`kubectl get pods -n flux-system`  
`flux get kustomizations -A`

---

## Gateway Application Programming Interface Custom Resource Definitions installieren

Gateway Application Programming Interface Custom Resource Definitions installieren:

`kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml`

Prüfen:

`kubectl get crds | grep gateway.networking.k8s.io`

---

## MetalLB installieren

MetalLB stellt für Services vom Typ LoadBalancer Internet Protocol Adressen im Heimnetz bereit.

Basisinstallation:

`kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml`

Pods prüfen:

`kubectl get pods -n metallb-system`

Hinweis zur Konfiguration:

- Die eigentliche MetalLB Konfiguration (IPAddressPool, L2Advertisement) liegt im Repository unter `kustomize/infra/metallb/`  
- Sie wird durch die Flux Kustomization `cluster-infra` automatisch angewendet  

---

## Secrets und Passwörter anlegen

Bestimmte Konfigurationen enthalten Passwörter oder andere Geheimnisse und dürfen nicht im Repository liegen.

Beispiele:

- Nextcloud Administrator Passwort  
- Datenbank Zugangsdaten  

### Nextcloud Administrator Secret

Beispiel (Production):

`kubectl create secret generic nextcloud-admin-secret \`  
`  --from-literal=admin-user="DEIN_BENUTZER" \`  
`  --from-literal=admin-password="DEIN_PASSWORT" \`  
`  -n nextcloud-production`

### MariaDB Secrets

Production:

`kubectl create secret generic nextcloud-mariadb \`  
`  -n nextcloud-production \`  
`  --from-literal=database=nextcloud \`  
`  --from-literal=username=nextcloud \`  
`  --from-literal=password='DEIN_STARKES_PASSWORT' \`  
`  --from-literal=root-password='DEIN_ROOT_PASSWORT'`

Staging:

`kubectl create secret generic nextcloud-mariadb \`  
`  -n nextcloud-staging \`  
`  --from-literal=database=nextcloud_staging \`  
`  --from-literal=username=nextcloud \`  
`  --from-literal=password='DEIN_STAGING_PASSWORT' \`  
`  --from-literal=root-password='DEIN_STAGING_ROOT_PASSWORT'`

---

## Notwendige Rechte vergeben

Clusterrolebindings anlegen:

`kubectl create clusterrolebinding source-controller-admin \`  
`  --clusterrole=cluster-admin \`  
`  --serviceaccount=flux-system:source-controller`

`kubectl create clusterrolebinding cert-manager-controller-admin \`  
`  --clusterrole=cluster-admin \`  
`  --serviceaccount=cert-manager:cert-manager`

`kubectl create clusterrolebinding helm-controller-admin \`  
`  --clusterrole=cluster-admin \`  
`  --serviceaccount=flux-system:helm-controller`

`kubectl create clusterrolebinding notification-controller-admin \`  
`  --clusterrole=cluster-admin \`  
`  --serviceaccount=flux-system:notification-controller`

`kubectl create clusterrolebinding metrics-server-admin \`  
`  --clusterrole=cluster-admin \`  
`  --serviceaccount=kube-system:metrics-server`

`kubectl create clusterrolebinding metallb-speaker-admin \`  
`  --clusterrole=cluster-admin \`  
`  --serviceaccount=metallb-system:metallb-speaker`

---

## Cert-Manager Custom Resource Definitions installieren

`kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.9.1/cert-manager.crds.yaml`

---

## Domainnamen ohne lokalen Domain Name System Server

Wenn kein Domain Name System Server im Heimnetz existiert, können Domainnamen lokal über die Hosts-Datei aufgelöst werden.

### Windows

Pfad:

- `C:\Windows\System32\drivers\etc\hosts`

Einträge hinzufügen:

`192.168.178.240  nextcloud.home.lan`  
`192.168.178.240  nextcloud.staging.home.lan`

### Linux oder macOS

Hosts-Datei bearbeiten:

`sudo nano /etc/hosts`

Einträge:

`192.168.178.240 nextcloud.home.lan`  
`192.168.178.240 nextcloud.staging.home.lan`

---

## Kubeconfig dauerhaft setzen

### k3s.yaml kopieren

`mkdir -p ~/.kube/configfile`  
`sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/configfile/k3s.yaml`

### Rechte setzen

`sudo chown "$USER:$USER" ~/.kube/configfile/k3s.yaml`  
`chmod 600 ~/.kube/configfile/k3s.yaml`

### Umgebungsvariable in /etc/environment setzen

`sudo nano /etc/environment`

Eintragen (Benutzerverzeichnis anpassen):

`KUBECONFIG="/home/DEIN_BENUTZER/.kube/configfile/k3s.yaml"`

---

## Pod Reset nach Neustart automatisieren

### Reset Skript

- Reset Skript liegt unter `docs/scripts/reset-cluster.sh`

### systemd Service erstellen

Service Datei anlegen:

`sudo nano /etc/systemd/system/reset-cluster.service`

Inhalt (komplett kopierbar):

```
[Unit]
Description=Reset Kubernetes cluster pods after boot
After=network-online.target k3s.service
Wants=network-online.target k3s.service

[Service]
Type=oneshot
User=homeserver
Group=homeserver
ExecStartPre=/bin/sleep 30
ExecStart=/home/homeserver/homeserver/docs/scripts/reset-cluster.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

Units neu laden:

`sudo systemctl daemon-reload`

Aktivieren und starten:

`sudo systemctl enable reset-cluster.service`  
`sudo systemctl start reset-cluster.service`

Status prüfen:

`sudo systemctl status reset-cluster.service -l`  
`journalctl -xeu reset-cluster.service`

Deaktivieren und stoppen:

`sudo systemctl disable reset-cluster.service`  
`sudo systemctl stop reset-cluster.service`

---

## Longhorn Host Voraussetzungen

Auf den Cluster Hosts `open-iscsi` installieren (Longhorn benötigt iSCSI für das Einhängen der Volumes).

Pakete installieren und Dienst aktivieren:

`sudo apt update`  
`sudo apt install -y open-iscsi nfs-common`  
`sudo systemctl enable --now iscsid`

Longhorn Komponenten neu starten:

`kubectl rollout restart daemonset longhorn-manager -n longhorn-system`  
`kubectl rollout restart deployment longhorn-driver-deployer -n longhorn-system`

---

## Gesamtstatus prüfen

Flux Status:

`flux get kustomizations -A`

Pods im gesamten Cluster:

`kubectl get pods -A`

Gateway Ressourcen:

`kubectl get gatewayclass`  
`kubectl get gateway -A`  
`kubectl get httproute -A`

---

## Nextcloud Erreichbarkeit

Nextcloud sollte erreichbar sein über:

- `nextcloud.staging.home.lan` (Staging)  
- `nextcloud.home.lan` (Production)  

Voraussetzung:

- Domainnamen müssen auf die LoadBalancer Internet Protocol Adresse des Gateways zeigen, die MetalLB vergeben hat.
