#!/bin/bash

# Anleitung zur Verwendung:
# Dieses Skript erstellt einen ZFS-Snapshot und sichert diesen auf ein XFS-Dateisystem.
# 
# Verwendung:
# ./zfs_to_xfs_backup.sh -backup
#
# Wiederherstellung:
# ./zfs_to_xfs_backup.sh -recovery <backup_directory>

# ZFS Dataset Konfiguration
ZFS_DATASET="fast/appdata2" # Ersetze dies mit deinem ZFS-Dataset
XFS_BACKUP_DIR="/mnt/user/docker_backup/new2"  # Ersetze dies mit deinem XFS-Backup-Ordner
TARGET_DATASET="fast/appdata3"  # Ersetze dies mit dem gewünschten Ziel-Dataset für die Wiederherstellung

# Anzahl der Tage, um alte Snapshots und Backups zu behalten
DAYS_TO_KEEP=7

# Funktion zum Aufräumen alter Snapshots
cleanup_old_snapshots() {
  echo "Bereinigen von alten Snapshots, die älter als $DAYS_TO_KEEP Tage sind..."
  for snapshot in $(zfs list -H -o name -t snapshot | grep "$ZFS_DATASET"); do
    creation_time=$(zfs get -H -o value creation "$snapshot")
    creation_timestamp=$(date -d "$creation_time" +%s)
    cutoff_timestamp=$(date -d "$DAYS_TO_KEEP days ago" +%s)

    if [ "$creation_timestamp" -lt "$cutoff_timestamp" ]; then
      echo "Lösche alten Snapshot: $snapshot"
      zfs destroy "$snapshot"
    fi
  done
}

# Funktion zum Aufräumen alter Backups
cleanup_old_backups() {
  echo "Bereinigen von alten Backups, die älter als $DAYS_TO_KEEP Tage sind..."
  find "$XFS_BACKUP_DIR" -type f -name "*.tar.gz" -mtime +$DAYS_TO_KEEP -exec rm -f {} \;

  # Überprüfen, ob es mehr als 7 Backups gibt und die ältesten löschen
  BACKUP_COUNT=$(find "$XFS_BACKUP_DIR" -type f -name "*.tar.gz" | wc -l)
  if [ "$BACKUP_COUNT" -gt 7 ]; then
    echo "Es sind bereits mehr als 7 Backups vorhanden. Lösche die ältesten Backups..."
    find "$XFS_BACKUP_DIR" -type f -name "*.tar.gz" | sort | head -n -7 | xargs rm -f
  fi
}

# Funktion, um einen ZFS-Snapshot zu erstellen
create_snapshot() {
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")  # Aktueller Zeitstempel
  SNAPSHOT_NAME="${ZFS_DATASET}@backup_${TIMESTAMP}"

  echo "Erstelle ZFS-Snapshot: $SNAPSHOT_NAME"
  zfs snapshot "$SNAPSHOT_NAME"
  
  if [ $? -ne 0 ]; then
    echo "Fehler beim Erstellen des Snapshots."
    exit 1
  fi

  echo "Snapshot erfolgreich erstellt: $SNAPSHOT_NAME"
  
  # Das Backup der Snapshot-Daten wird erstellt
  backup_data "$SNAPSHOT_NAME"
}

# Funktion, um die Snapshot-Daten auf das XFS-Dateisystem zu sichern
backup_data() {
  SNAPSHOT_NAME="$1"
  BACKUP_DIR="${XFS_BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
  
  echo "Sichere ZFS-Snapshot: $SNAPSHOT_NAME nach $BACKUP_DIR"
  
  # Erstelle das Backup-Verzeichnis
  mkdir -p "$BACKUP_DIR"

  # Verwende rsync, um die Daten ins Backup-Verzeichnis zu kopieren
  rsync -a --delete "$(zfs get -H -o value mountpoint "$ZFS_DATASET")/" "$BACKUP_DIR/"
  
  if [ $? -eq 0 ]; then
    echo "Backup erfolgreich in $BACKUP_DIR gesichert."
    # Komprimiere das Backup-Verzeichnis in ein tar.gz-Archiv
    tar -czf "${BACKUP_DIR}.tar.gz" -C "$XFS_BACKUP_DIR" "$(basename "$BACKUP_DIR")"
    echo "Backup erfolgreich in ${BACKUP_DIR}.tar.gz komprimiert."
    # Lösche das unkomprimierte Backup-Verzeichnis
    rm -rf "$BACKUP_DIR"
  else
    echo "Fehler beim Sichern des Snapshots."
  fi
}

# Funktion zur Auflistung von verfügbaren Backups
list_backups() {
  echo "Verfügbare Backups:"
  ls -1 "$XFS_BACKUP_DIR"/*.tar.gz
}

# Funktion, um ein Backup wiederherzustellen
recovery() {
  BACKUP_FILE="$1"

  if [ -z "$BACKUP_FILE" ]; then
    echo "Bitte eine Backup-Datei angeben."
    exit 1
  fi

  if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup-Datei $BACKUP_FILE wurde nicht gefunden."
    exit 1
  fi

  echo "Wiederherstellung aus Backup-Datei: $BACKUP_FILE"

  # Entpacke das Backup und sende die Daten an ZFS
  tar -xzf "$BACKUP_FILE" -C "$(zfs get -H -o value mountpoint "$TARGET_DATASET")/"

  if [ $? -eq 0 ]; then
    echo "Wiederherstellung erfolgreich aus $BACKUP_FILE zu $TARGET_DATASET."
  else
    echo "Fehler bei der Wiederherstellung aus der Backup-Datei."
  fi
}

# Auswahl der Funktion basierend auf dem Eingabeargument
case "$1" in
    -backup)
        cleanup_old_snapshots  # Alte Snapshots bereinigen
        cleanup_old_backups  # Alte Backups bereinigen
        create_snapshot  # Backup-Funktion aufrufen
        ;;
    -recovery)
        list_backups  # Verfügbare Backups auflisten
        echo "Bitte geben Sie den vollständigen Pfad zur Backup-Datei ein, die Sie wiederherstellen möchten:"
        read BACKUP_FILE  # Backup-Datei vom Benutzer abfragen
        recovery "$BACKUP_FILE"  # Wiederherstellungs-Funktion aufrufen
        ;;
    *)
        echo "Ungültiges Argument. Bitte verwenden Sie -backup oder -recovery."
        exit 1
        ;;
esac