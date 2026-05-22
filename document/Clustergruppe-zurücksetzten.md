# Kubernetes :: Clustergruppe zurücksetzen

Diese Anleitung beschreibt, wie eine über Flux verwaltete Clustergruppe beziehungsweise Anwendungsgruppe zurückgesetzt werden kann.  
Das Beispiel basiert auf der Staging-Umgebung von Nextcloud mit MariaDB.

Der Reset löscht die persistenten Daten der ausgewählten Umgebung. Danach erzeugt Flux die Ressourcen wieder aus dem Git Repository.

---

## Ziel

Ein Reset ist sinnvoll, wenn eine Staging-Umgebung neu initialisiert werden soll, zum Beispiel weil:

- der Administratorzugang nicht mehr funktioniert
- Testdaten verworfen werden sollen
- die Datenbank neu aufgebaut werden soll
- eine Anwendung wieder aus dem GitOps-Zustand heraus frisch starten soll

---

## Wichtiger Hinweis

Diese Schritte löschen Daten.

Bei Nextcloud liegen wichtige Daten nicht nur im Nextcloud-Container, sondern auch in der MariaDB-Datenbank.  
Ein reiner Neustart des Containers reicht deshalb nicht aus.

Für einen vollständigen Reset müssen gelöscht werden:

- Persistent Volume Claim der Anwendung
- Persistent Volume Claim der Datenbank

Secrets werden in dieser Anleitung nicht gelöscht, damit Benutzername, Passwort, Datenbankname und Datenbankzugang erhalten bleiben.

---

## Beispielumgebung

In diesem Beispiel wird die Staging-Umgebung zurückgesetzt:

```text
Namespace: nextcloud-staging
Flux Kustomization: cluster-apps-staging
Flux Namespace: flux-system
Anwendung: Nextcloud
Datenbank: MariaDB
```

---

## 1. Flux Kustomization pausieren

Zuerst wird die Flux Kustomization pausiert.  
Dadurch verhindert man, dass Flux während des Resets sofort wieder Ressourcen verändert.

```bash
flux suspend kustomization cluster-apps-staging -n flux-system
```

Erwartete Ausgabe:

```text
kustomization suspended
```

---

## 2. Aktuelle Ressourcen anzeigen

Vor dem Löschen sollte geprüft werden, welche Ressourcen im Namespace vorhanden sind.

```bash
kubectl get deploy,pod,pvc,svc -n nextcloud-staging
```

Typische Ausgabe:

```text
deployment.apps/mariadb-nextcloud
deployment.apps/nextcloud

pod/mariadb-nextcloud-...
pod/nextcloud-...

persistentvolumeclaim/mariadb-data
persistentvolumeclaim/nextcloud-data

service/mariadb-nextcloud
service/nextcloud
```

Wichtig sind vor allem die Persistent Volume Claims:

```text
mariadb-data
nextcloud-data
```

---

## 3. Deployments stoppen

Damit die Persistent Volume Claims sauber gelöscht werden können, werden die Deployments auf null Replikate skaliert.

```bash
kubectl scale deploy --all -n nextcloud-staging --replicas=0
```

Danach prüfen, ob keine Pods mehr laufen:

```bash
kubectl get pods -n nextcloud-staging
```

Erwartete Ausgabe:

```text
No resources found in nextcloud-staging namespace.
```

---

## 4. Persistent Volume Claims löschen

Wenn in dem Namespace nur die zurückzusetzende Umgebung liegt, können alle Persistent Volume Claims gelöscht werden.

```bash
kubectl delete pvc --all -n nextcloud-staging
```

Danach prüfen:

```bash
kubectl get pvc -n nextcloud-staging
```

Erwartete Ausgabe:

```text
No resources found in nextcloud-staging namespace.
```

---

## 5. Flux Kustomization wieder aktivieren

Jetzt wird Flux wieder aktiviert.

```bash
flux resume kustomization cluster-apps-staging -n flux-system
```

Danach kann die Synchronisierung manuell angestoßen werden:

```bash
flux reconcile kustomization cluster-apps-staging -n flux-system
```

---

## 6. Prüfen, ob die Umgebung neu erstellt wurde

Pods beobachten:

```bash
kubectl get pods -n nextcloud-staging -w
```

Wenn die Pods laufen, kann die Beobachtung mit `Strg + C` beendet werden.

Danach Persistent Volume Claims prüfen:

```bash
kubectl get pvc -n nextcloud-staging
```

Erwartete Ausgabe:

```text
mariadb-data     Bound
nextcloud-data   Bound
```

Die Persistent Volume Claims sollten ein neues Alter haben, zum Beispiel wenige Minuten.

---

## 7. Secrets prüfen

Secrets werden bei diesem Reset nicht gelöscht.  
Dadurch bleiben die gespeicherten Zugangsdaten erhalten.

Secrets im Namespace anzeigen:

```bash
kubectl get secret -n nextcloud-staging
```

Beispiel:

```text
nextcloud-mariadb
```

Secret-Schlüssel anzeigen, ohne die Werte offenzulegen:

```bash
kubectl get secret nextcloud-mariadb -n nextcloud-staging -o jsonpath='{.data}' | jq 'keys'
```

Falls `jq` nicht installiert ist:

```bash
kubectl get secret nextcloud-mariadb -n nextcloud-staging -o yaml
```

In der Ausgabe stehen unter `data:` die vorhandenen Schlüssel.

---

## 8. Einzelne Secret-Werte auslesen

Wichtig: Platzhalter wie `<SECRET-NAME>` oder `<KEY>` dürfen nicht direkt in die Shell kopiert werden.  
Sie müssen vorher durch echte Werte ersetzt werden.

Falsch:

```bash
kubectl get secret <SECRET-NAME> -n nextcloud-staging -o jsonpath='{.data.<KEY>}' | base64 -d
```

Richtiges Muster:

```bash
kubectl get secret nextcloud-mariadb -n nextcloud-staging -o jsonpath='{.data.SCHLUESSELNAME}' | base64 -d
```

Beispiel, wenn ein Schlüssel `mariadb-password` heißt:

```bash
kubectl get secret nextcloud-mariadb -n nextcloud-staging -o jsonpath='{.data.mariadb-password}' | base64 -d
```

Beispiel, wenn ein Schlüssel `password` heißt:

```bash
kubectl get secret nextcloud-mariadb -n nextcloud-staging -o jsonpath='{.data.password}' | base64 -d
```

---

## 9. Nextcloud nach dem Reset prüfen

Nach dem Reset kann die Anwendung erneut getestet werden.

```bash
curl -I https://nextcloud-staging.home.lan/
```

Wenn das Zertifikat lokal vertraut ist, sollte der Aufruf ohne Zertifikatsfehler funktionieren.

Wenn nur ein technischer Test nötig ist:

```bash
curl -k -I https://nextcloud-staging.home.lan/
```

---

## 10. Nextcloud HTTPS-Konfiguration prüfen oder setzen

Nach einem Reset kann es nötig sein, die Nextcloud-Systemkonfiguration erneut zu setzen.

In den Container wechseln:

```bash
kubectl exec -it -n nextcloud-staging deploy/nextcloud -- bash
```

Konfiguration als Webserver-Benutzer setzen:

```bash
su -s /bin/bash www-data -c "php occ config:system:set overwritehost --value=nextcloud-staging.home.lan"
su -s /bin/bash www-data -c "php occ config:system:set overwriteprotocol --value=https"
su -s /bin/bash www-data -c "php occ config:system:set overwrite.cli.url --value=https://nextcloud-staging.home.lan"
su -s /bin/bash www-data -c "php occ config:system:set trusted_domains 1 --value=nextcloud-staging.home.lan"
su -s /bin/bash www-data -c "php occ maintenance:repair"
```

Container verlassen:

```bash
exit
```

---

## 11. Kompakte Befehlsfolge für Staging-Reset

Diese Befehle setzen die Staging-Umgebung vollständig zurück, ohne Secrets zu löschen:

```bash
flux suspend kustomization cluster-apps-staging -n flux-system

kubectl get deploy,pod,pvc,svc -n nextcloud-staging

kubectl scale deploy --all -n nextcloud-staging --replicas=0

kubectl get pods -n nextcloud-staging

kubectl delete pvc --all -n nextcloud-staging

kubectl get pvc -n nextcloud-staging

flux resume kustomization cluster-apps-staging -n flux-system

flux reconcile kustomization cluster-apps-staging -n flux-system

kubectl get pods -n nextcloud-staging -w

kubectl get pvc -n nextcloud-staging
```

---

## 12. Anpassung für andere Clustergruppen

Für andere Umgebungen müssen die Namen angepasst werden.

Beispiel für Production:

```text
Namespace: nextcloud-production
Flux Kustomization: cluster-apps-production
```

Dann entsprechend:

```bash
flux suspend kustomization cluster-apps-production -n flux-system
kubectl scale deploy --all -n nextcloud-production --replicas=0
kubectl delete pvc --all -n nextcloud-production
flux resume kustomization cluster-apps-production -n flux-system
flux reconcile kustomization cluster-apps-production -n flux-system
```

Production sollte nur zurückgesetzt werden, wenn der Datenverlust ausdrücklich gewollt ist.

---

## 13. Typische Fehler

### Fehler: Platzhalter wurde direkt kopiert

Fehlerhafte Eingabe:

```bash
kubectl get secret <SECRET-NAME> -n nextcloud-staging -o jsonpath='{.data.NEXTCLOUD_ADMIN_PASSWORD}' | base64 -d
```

Mögliche Fehlermeldung:

```text
bash: SECRET-NAME: No such file or directory
```

Ursache:

Die Shell interpretiert `<SECRET-NAME>` als Dateiumleitung.

Lösung:

Platzhalter durch echte Namen ersetzen, zum Beispiel:

```bash
kubectl get secret nextcloud-mariadb -n nextcloud-staging -o yaml
```

Danach den tatsächlichen Schlüssel aus `data:` verwenden.

---

### Fehler: Anwendung wurde zurückgesetzt, aber Anmeldung funktioniert nicht

Mögliche Ursachen:

- das Secret enthält andere Zugangsdaten als erwartet
- die Anwendung wurde noch nicht vollständig initialisiert
- die Datenbank ist noch nicht bereit
- der Browser hat alte Cookies oder alte Sitzungen gespeichert

Prüfen:

```bash
kubectl get pods -n nextcloud-staging
kubectl logs -n nextcloud-staging deploy/nextcloud --tail=100
kubectl logs -n nextcloud-staging deploy/mariadb-nextcloud --tail=100
```

---

## 14. Merksatz

Ein Kubernetes Deployment zu löschen oder neu zu starten löscht keine Anwendungsdaten.  
Persistente Daten liegen in Persistent Volume Claims.  
Bei Anwendungen mit Datenbank müssen Anwendungsspeicher und Datenbankspeicher gemeinsam betrachtet werden.
