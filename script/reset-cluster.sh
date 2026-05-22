#!/bin/bash

echo "Cluster Reset gestartet..."

# Liste aller Namespaces holen, kube-system überspringen
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')

for ns in $namespaces; do
    case $ns in
        kube-system)
            echo "Überspringe kube-system..."
            ;;
        *)
            echo "Lösche Pods in Namespace: $ns"
            kubectl delete pod --all -n "$ns" --ignore-not-found
            ;;
    esac
done

echo "Cluster Reset abgeschlossen."
