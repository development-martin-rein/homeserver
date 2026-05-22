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
- [GitLab Production Instanz installieren](#gitlab-production-instanz-installieren)
  - [GitLab Verzeichnisstruktur anlegen](#gitlab-verzeichnisstruktur-anlegen)
  - [GitLab Namespace anlegen](#gitlab-namespace-anlegen)
  - [GitLab HelmRepository anlegen](#gitlab-helmrepository-anlegen)
  - [GitLab HelmRelease anlegen](#gitlab-helmrelease-anlegen)
  - [GitLab in Production einbinden](#gitlab-in-production-einbinden)
  - [GitLab über Flux ausrollen](#gitlab-über-flux-ausrollen)
  - [GitLab HTTPRoute anlegen](#gitlab-httproute-anlegen)
  - [GitLab Root Passwort auslesen](#gitlab-root-passwort-auslesen)
  - [GitLab Erreichbarkeit prüfen](#gitlab-erreichbarkeit-prüfen)
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

---

## GitLab Production Instanz installieren

Dieses Kapitel beschreibt die Installation einer einzelnen GitLab Instanz im Production Bereich des Clusters.

Die GitLab Instanz wird über Flux und die GitLab Helm Chart installiert.

Ziel:

- Namespace: `gitlab-production`
- Adresse: `gitlab.system`
- Speicherklasse: `longhorn`
- Zugriff über Envoy Gateway und HTTPRoute
- Kein GitLab Runner bei der Erstinstallation
- Kein eigener GitLab Cert-Manager, da Cert-Manager bereits zentral im Cluster installiert ist
- Kein eigener GitLab Nginx Ingress Controller, da Envoy Gateway verwendet wird

---

### GitLab Verzeichnisstruktur anlegen

In das Repository wechseln:

`cd ~/homeserver`

GitLab Verzeichnis unter Production anlegen:

`mkdir -p kustomize/production/gitlab`

Zielstruktur:

```text
kustomize/
└── production/
    ├── kustomization.yaml
    ├── nextcloud/
    ├── mariadb-nextcloud/
    └── gitlab/
        ├── namespace.yaml
        ├── helmrepository.yaml
        ├── helmrelease.yaml
        ├── httproute.yaml
        └── kustomization.yaml
        
Hinweis:

- Dateien im Repository sollten ohne `sudo` bearbeitet werden.
- Das Repository liegt unter `/home/homeserver/homeserver`.
- Nicht versehentlich Pfade wie `/kustomize/...` verwenden.

---

## GitLab Namespace anlegen

Datei erstellen:

```text
cat > kustomize/production/gitlab/namespace.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: gitlab-production
EOF
```

---

## GitLab HelmRepository anlegen

Datei erstellen:

```text
cat > kustomize/production/gitlab/helmrepository.yaml <<'EOF'
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: gitlab
  namespace: gitlab-production
spec:
  interval: 1h
  url: https://charts.gitlab.io/
EOF
```

---

## GitLab HelmRelease anlegen

Datei erstellen:

```text
cat > kustomize/production/gitlab/helmrelease.yaml <<'EOF'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: gitlab
  namespace: gitlab-production
spec:
  interval: 30m
  timeout: 20m
  chart:
    spec:
      chart: gitlab
      sourceRef:
        kind: HelmRepository
        name: gitlab
        namespace: gitlab-production
      interval: 12h
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  values:
    global:
      edition: ce
      hosts:
        domain: system
        https: false
        gitlab:
          name: gitlab.system
      ingress:
        enabled: false
        configureCertmanager: false
        tls:
          enabled: false
      gatewayApi:
        configureCertmanager: false
      storage:
        class: longhorn
    installCertmanager: false
    nginx-ingress:
      enabled: false
    prometheus:
      install: false
    gitlab-runner:
      install: false
    registry:
      enabled: false
    gitlab:
      webservice:
        minReplicas: 1
        maxReplicas: 1
      sidekiq:
        minReplicas: 1
        maxReplicas: 1
      gitaly:
        persistence:
          storageClass: longhorn
          size: 50Gi
      toolbox:
        persistence:
          storageClass: longhorn
          size: 10Gi
    postgresql:
      install: true
      primary:
        persistence:
          storageClass: longhorn
          size: 20Gi
    redis:
      install: true
    minio:
      persistence:
        storageClass: longhorn
        size: 20Gi
EOF
```

Wichtige Hinweise:

- `installCertmanager: false` verhindert, dass GitLab einen eigenen Cert-Manager im Namespace `gitlab-production` installiert.
- `global.ingress.configureCertmanager: false` verhindert, dass GitLab Cert-Manager für Ingress Ressourcen konfigurieren möchte.
- `global.gatewayApi.configureCertmanager: false` verhindert, dass GitLab Cert-Manager für Gateway Application Programming Interface Ressourcen konfigurieren möchte.
- `nginx-ingress.enabled: false` ist notwendig, weil Envoy Gateway verwendet wird.
- `gitlab-runner.install: false` ist bewusst gesetzt. Der Runner sollte erst nach erfolgreicher GitLab Grundinstallation eingerichtet werden.
- `registry.enabled: false` deaktiviert zunächst die GitLab Container Registry.

---

## GitLab Kustomization anlegen

Datei erstellen:

```text
cat > kustomize/production/gitlab/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - helmrepository.yaml
  - helmrelease.yaml
EOF
```

---

## GitLab in Production einbinden

Die vorhandene Production Kustomization öffnen:

`nano kustomize/production/kustomization.yaml`

GitLab als Resource ergänzen:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - nextcloud
  - mariadb-nextcloud
  - gitlab
```

---

## GitLab über Flux ausrollen

Änderungen prüfen:

`git status`

Änderungen einchecken:

`git add kustomize/production/gitlab kustomize/production/kustomization.yaml`
`git commit -m "Add GitLab production deployment"`
`git push`

Flux anstoßen:

`flux reconcile source git flux-system -n flux-system`
`flux reconcile kustomization cluster-apps-production -n flux-system`

Falls der Name der Flux Kustomization unbekannt ist:

`flux get kustomizations -A`

Installation beobachten:

`flux get helmreleases -A`
`kubectl get pods -n gitlab-production`
`kubectl get persistentvolumeclaims -n gitlab-production`
`kubectl get services -n gitlab-production`

Alle GitLab Pods beobachten:

`kubectl get pods -n gitlab-production -w`

---

## GitLab HTTPRoute anlegen

Nach erfolgreicher Installation den Webservice prüfen:

`kubectl get services -n gitlab-production`

Der relevante Service heißt normalerweise:

`gitlab-webservice-default`

Er besitzt unter anderem folgende Ports:

- `8080`
- `8181`
- `8083`

HTTPRoute Datei erstellen:

```text
cat > kustomize/production/gitlab/httproute.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: gitlab
  namespace: gitlab-production
spec:
  parentRefs:
    - name: home-gateway
      namespace: gateway-system
  hostnames:
    - gitlab.system
  rules:
    - backendRefs:
        - name: gitlab-webservice-default
          port: 8181
EOF
```

HTTPRoute in die GitLab Kustomization aufnehmen:

`nano kustomize/production/gitlab/kustomization.yaml`

Datei sollte danach so aussehen:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - helmrepository.yaml
  - helmrelease.yaml
  - httproute.yaml
```

Änderungen einchecken:

`git add kustomize/production/gitlab`
`git commit -m "Expose GitLab through Envoy Gateway"`
`git push`

Flux erneut anstoßen:

`flux reconcile source git flux-system -n flux-system`
`flux reconcile kustomization cluster-apps-production -n flux-system`

HTTPRoute prüfen:

`kubectl get httproute -A`
`kubectl describe httproute -n gitlab-production gitlab`

Im Status sollte die Route angenommen sein.

Wichtige Statuswerte:

- `Accepted: True`
- `ResolvedRefs: True`

---

## GitLab Root Passwort auslesen

Initiales Root Passwort aus dem Secret auslesen:

`kubectl get secret -n gitlab-production gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 -d; echo`

Benutzername:

`root`

Passwort anschließend sicher in einem Passwortmanager speichern.

---

## GitLab Erreichbarkeit prüfen

GitLab sollte erreichbar sein über:

- `http://gitlab.system`

Voraussetzung:

- `gitlab.system` muss auf die LoadBalancer Internet Protocol Adresse des Gateways zeigen.
- Im aktuellen Cluster ist dies üblicherweise die MetalLB Adresse des Envoy Gateways.

LoadBalancer Adresse prüfen:

`kubectl get services -A | grep LoadBalancer`

Falls kein lokaler Domain Name System Server vorhanden ist, muss die Hosts-Datei auf dem Client angepasst werden.

Windows Hosts-Datei:

- `C:\Windows\System32\drivers\etc\hosts`

Eintrag:

`192.168.178.241 gitlab.system`

Linux oder macOS Hosts-Datei bearbeiten:

`sudo nano /etc/hosts`

Eintrag:

`192.168.178.241 gitlab.system`

Danach im Browser öffnen:

`http://gitlab.system`

---

## GitLab Status prüfen

Pods prüfen:

`kubectl get pods -n gitlab-production`

Services prüfen:

`kubectl get services -n gitlab-production`

Persistent Volume Claims prüfen:

`kubectl get persistentvolumeclaims -n gitlab-production`

HelmRelease prüfen:

`flux get helmreleases -A`

Details zum HelmRelease anzeigen:

`kubectl describe helmrelease gitlab -n gitlab-production`

HTTPRoute prüfen:

`kubectl describe httproute -n gitlab-production gitlab`

---

## Bedeutung von Completed Pods bei GitLab

Bei GitLab können nach der Installation Pods mit dem Status `Completed` sichtbar sein.

Beispiele:

- `gitlab-migrations-...`
- `gitlab-minio-create-buckets-...`

Das ist normal.

Bedeutung:

- `gitlab-migrations-...` führt einmalig Datenbankmigrationen aus.
- `gitlab-minio-create-buckets-...` legt einmalig benötigte MinIO Buckets an.
- Der Status `Completed` bedeutet, dass der Job erfolgreich beendet wurde.
- `0/1 Completed` ist bei solchen einmaligen Jobs kein Fehler.

Jobs prüfen:

`kubectl get jobs -n gitlab-production`

Logs der Migrationen prüfen:

`kubectl logs -n gitlab-production job/gitlab-migrations-3385e37`

Logs des MinIO Bucket Jobs prüfen:

`kubectl logs -n gitlab-production job/gitlab-minio-create-buckets-b318e56`

Hinweis:

- Die Job Namen können sich bei späteren Installationen oder Aktualisierungen ändern.
- Den aktuellen Job Namen erhält man mit `kubectl get jobs -n gitlab-production`.

---

## GitLab Testprojekt anlegen

Nach erfolgreicher Anmeldung in GitLab ein Testprojekt anlegen:

- Neues Projekt erstellen
- Blank Project auswählen
- Name: `test`
- Sichtbarkeit: Private

HTTP Clone testen:

`git clone http://gitlab.system/root/test.git`

Empfehlung:

- Für Git Operationen nicht dauerhaft das Root Passwort verwenden.
- Stattdessen in GitLab einen Personal Access Token anlegen.
- Für einen einfachen Repository Test reichen die Rechte `read_repository` und `write_repository`.

---

## Hinweis zu GitLab SSH Zugriff

Die Weboberfläche läuft über HTTPRoute und Envoy Gateway.

Der GitLab SSH Zugriff läuft über den Service:

`gitlab-gitlab-shell`

Dieser Service ist standardmäßig nur als ClusterIP erreichbar:

`kubectl get service -n gitlab-production gitlab-gitlab-shell`

Das bedeutet:

`git clone http://gitlab.system/root/test.git`

funktioniert über HTTP.

Aber:

`git clone git@gitlab.system:root/test.git`

funktioniert erst, wenn SSH zusätzlich nach außen veröffentlicht wird.

Der SSH Zugriff sollte daher separat geplant und erst nach erfolgreicher Grundinstallation eingerichtet werden.

---

## GitLab Runner später einrichten

Der GitLab Runner wird bei der Grundinstallation bewusst nicht installiert:

`gitlab-runner:`
`  install: false`

Grund:

- Erst soll GitLab selbst stabil laufen.
- Danach kann der Runner separat eingerichtet werden.
- Der Runner erzeugt für Pipeline Jobs eigene Pods im Cluster.
- Dafür sollten Berechtigungen, Namespace und Ressourcenlimits getrennt geplant werden.

Empfohlene Reihenfolge:

1. GitLab Weboberfläche erreichbar machen
2. Root Anmeldung testen
3. Testprojekt anlegen
4. HTTP Clone testen
5. Backup Konzept prüfen
6. Erst danach GitLab Runner einrichten
