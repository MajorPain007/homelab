#!/bin/bash

# Anleitung zur Verwendung:
# Dieses Skript erstellt Backups von Docker-Containern und ermöglicht die Wiederherstellung spezifischer Container.
# 
# Verwendung:
# Backup erstellen:
# ./backup_docker.sh -backup
# 
# Wiederherstellung:
# Um einen oder mehrere Container wiederherzustellen, führe das Skript mit dem Argument -recovery gefolgt von den Namen der Container aus:
# ./backup_docker.sh -recovery container1 container2

# Variablen für die Quell- und Zielverzeichnisse
SOURCE_DIR="/mnt/user/appdata/dockge/stacks"  # Pfad zu deinen Docker-Ordnern
BACKUP_DIR="/mnt/user/docker_backup/new"  # Pfad zum Backup-Ordner



# Funktion, um Backups zu erstellen
backup() {



  # Erstelle Backup-Ordner, wenn er nicht existiert
  mkdir -p "$BACKUP_FOLDER"

  # Finde übergeordnete Ordner und erstelle inkrementelle, komprimierte Backups direkt
  for dir in "$SOURCE_DIR"/*; do
    if [ -d "$dir" ]; then



      # Führe die inkrementelle Sicherung durch und prüfe auf Fehler
      if rsync -a --ignore-existing --exclude '*/' "$dir/" "$BACKUP_FOLDER/$BASE_DIR_NAME/"; then
        # Komprimiere den Ordner zu einer TAR.GZ-Datei
        tar -czf "$BACKUP_FILE" -C "$BACKUP_FOLDER" "$BASE_DIR_NAME/"

        # Lösche den rsync-Ordner nach der Komprimierung
        rm -rf "$BACKUP_FOLDER/$BASE_DIR_NAME/"
      else

      fi  

      # Lösche alte Backups, wenn mehr als MAX_BACKUPS vorhanden sind

      if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
        echo "Es sind bereits $MAX_BACKUPS Backups vorhanden für $BASE_DIR_NAME. Löschen von alten Backups."
        find "$BACKUP_FOLDER" -type f -name "${BASE_DIR_NAME}_*.tar.gz" | sort | head -n -$MAX_BACKUPS | xargs rm -rf
      fi
    fi
  done

  # Lösche Backups, die älter als die angegebene Anzahl an Tagen sind
  find "$BACKUP_FOLDER" -type f -name "*.tar.gz" -mtime +$DAYS_TO_KEEP -exec rm -rf {} \;


}

# Funktion, um Backups wiederherzustellen
recovery() {
  for container in "$@"; do
    # Suche die neueste Backup-Datei für den angeforderten Container


    if [ -f "$BACKUP_FILE" ]; then
      echo "Wiederherstellung für $container von $BACKUP_FILE ..."
      # Entpacken der Backup-Datei direkt in das Zielverzeichnis
      tar -xzf "$BACKUP_FILE" -C "$SOURCE_DIR"
      
      # Der entpackte Ordner behält den ursprünglichen Namen
      echo "Wiederherstellung für $container abgeschlossen. Der Ordner heißt jetzt $container."
    else
      echo "Backup-Datei für $container nicht gefunden."
    fi
  done
}

# Auswahl der Funktion basierend auf dem Eingabeargument
case "$1" in
    -backup)
        backup  # Backup-Funktion aufrufen
        ;;
    -recovery)
        shift  # Entferne das erste Argument, um die Container-Namen zu erhalten
        recovery "$@"  # Recovery-Funktion mit den gegebenen Containern aufrufen
        ;;
    *)
        echo "Ungültiges Argument. Bitte verwenden Sie -backup oder -recovery gefolgt von den Namen der Container."
        exit 1
        ;;
esac
