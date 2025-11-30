#!/usr/bin/env bash
set -euo pipefail

echo "==========================================="
echo " Cluster Bootstrap – Infrastruktur-Basis  "
echo " (Gateway API CRDs + MetalLB Installation)"
echo "==========================================="
echo

# Kleine Sicherheitsabfrage
read -r -p "Achtung: Dies wird Ressourcen im aktuellen Kubernetes Kontext anlegen. Fortfahren? [y/N] " answer
case "$answer" in
  [Yy]* ) echo "Starte Bootstrap...";;
  * ) echo "Abgebrochen."; exit 0;;
esac

echo
echo "1/3) Prüfe aktuellen Kubernetes Kontext..."
kubectl config current-context || {
  echo "Fehler: Kein gültiger Kubernetes Kontext gefunden."
  exit 1
}
kubectl get nodes -o wide || {
  echo "Fehler: Knoten konnten nicht abgefragt werden."
  exit 1
}

echo
echo "2/3) Installiere Gateway API CRDs (standard-install)..."
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

echo
echo "   → Prüfe Gateway API CRDs..."
kubectl get crds | grep gateway.networking.k8s.io || {
  echo "Warnung: Gateway API CRDs wurden nicht gefunden."
}

echo
echo "3/3) Installiere MetalLB (Controller + Speaker + CRDs)..."
kubectl apply -f \
  https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml

echo
echo "   → Warte auf MetalLB Pods im Namespace metallb-system..."
kubectl wait --namespace metallb-system \
  --for=condition=Available deploy/controller \
  --timeout=180s || echo "Hinweis: controller Deployment nicht rechtzeitig Ready."

kubectl get pods -n metallb-system

cat <<EOF

===========================================================
 Bootstrap abgeschlossen (Basis-Infrastruktur):

 - Gateway API CRDs installiert
 - MetalLB Controller + Speaker installiert

Die eigentliche Konfiguration (IPAddressPool, L2Advertisement)
liegt GitOps-gesteuert im Repository unter:

  kustomize/infra/metallb/

und wird durch die Flux Kustomization 'cluster-infra'
automatisch angewendet, sobald Flux läuft.

Nächste typische Schritte (manuell ausführen):

  # Flux bootstrappen (falls noch nicht geschehen)
  # (GITHUB_USER und GITHUB_TOKEN vorher setzen)
  # flux bootstrap github \\
  #   --owner=\$GITHUB_USER \\
  #   --repository=homeserver \\
  #   --branch=main \\
  #   --path=clusters/my-cluster \\
  #   --personal

  # Status prüfen
  flux get kustomizations -A
  kubectl get gatewayclass
  kubectl get gateway -A
  kubectl get httproute -A

===========================================================
EOF
