# Cluster Bootstrap Anleitung

Dieses Dokument beschreibt die Schritte, um ein frisches k3s Cluster mit diesem Repository zu verbinden und alle erforderlichen Infrastrukturkomponenten zu installieren.

---

## 1. k3s installieren

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

2. Flux installieren und mit GitHub Repository verbinden

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


3. Gateway API CRDs installieren
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

Prüfen:
kubectl get crds | grep gateway.networking.k8s.io

4. MetalLB installieren

MetalLB stellt für Services vom Typ LoadBalancer IP-Adressen im Heimnetz bereit.

Basisinstallation (Controller + Speaker + CRDs):
kubectl apply -f \
  https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml

Pods prüfen:
kubectl get pods -n metallb-system

Die eigentliche Konfiguration von MetalLB (IPAddressPool, L2Advertisement) liegt im Git Repository unter kustomize/infra/metallb/ und wird durch die Flux Kustomization cluster-infra automatisch angewendet.

5. Secrets und Passwörter anlegen

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

6. Überprüfen, ob alles läuft
flux get kustomizations -A

kubectl get pods -A

kubectl get gatewayclass
kubectl get gateway -A
kubectl get httproute -A

Nextcloud sollte erreichbar sein über:

nextcloud.staging.home.lan (Staging)

nextcloud.home.lan (Production)

Voraussetzung ist, dass die DNS Einträge im Heimnetz auf die LoadBalancer IP des Gateways zeigen, die MetalLB vergeben hat.
