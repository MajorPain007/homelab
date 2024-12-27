#!/bin/bash

# Prerequisites: curl, jq (for JSON parsing, if needed)
# You can install jq with "sudo apt-get install jq"

# Arrays for Sonarr
SONARR_URLS=("http://localhost:8989" "http://other-url-sonarr:8989")
SONARR_API_KEYS=("sonarr_api_key_1" "sonarr_api_key_2")

# Arrays for Radarr
RADARR_URLS=("http://localhost:7878" "http://other-url-radarr:7878")
RADARR_API_KEYS=("radarr_api_key_1" "radarr_api_key_2")

# Change the NamingConfig for Sonarr
change_sonarr_naming_config() {
  local naming_json='{
    "id": 1,
    "renameEpisodes": true,
    "replaceIllegalCharacters": true,
    "colonReplacementFormat": 4,
    "customColonReplacementFormat": "Smart Replace",
    "multiEpisodeStyle": 5,
    "standardEpisodeFormat": "{Series TitleYear} - S{season:00}E{episode:00} - [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}",
    "dailyEpisodeFormat": "{Series TitleYear} - {Air-Date} - [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}",
    "animeEpisodeFormat": "{Series TitleYear} - S{season:00}E{episode:00} - {absolute:000} - [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}",
    "seriesFolderFormat": "{Series TitleYear} {tvdb-{TvdbId}}",
    "seasonFolderFormat": "Season {season:00}",
    "specialsFolderFormat": "Specials"
  }'

  for i in "${!SONARR_URLS[@]}"; do
    curl -X PUT "${SONARR_URLS[$i]}/api/v3/config/naming" \
      -H "X-Api-Key: ${SONARR_API_KEYS[$i]}" \
      -H "Content-Type: application/json" \
      -d "$naming_json"
  done
}

# Change the MediaManagementConfig for Sonarr
change_sonarr_mediamanagement_config() {
  local media_management_json='{
    "id": 1,
    "autoUnmonitorPreviouslyDownloadedEpisodes": false,
    "recycleBinCleanupDays": 7,
    "downloadPropersAndRepacks": "doNotPrefer",
    "createEmptySeriesFolders": false,
    "deleteEmptyFolders": false,
    "fileDate": "2",
    "rescanAfterRefresh": "always",
    "setPermissionsLinux": false,
    "chmodFolder": "",
    "chownGroup": "",
    "episodeTitleRequired": "always",
    "skipFreeSpaceCheckWhenImporting": false,
    "minimumFreeSpaceWhenImporting": 100,
    "copyUsingHardlinks": false,
    "useScriptImport": false,
    "importExtraFiles": true,
    "extraFileExtensions": "srt,sub,idx,vob,nfo",
    "enableMediaInfo": true
  }'

  for i in "${!SONARR_URLS[@]}"; do
    curl -X PUT "${SONARR_URLS[$i]}/api/v3/config/mediamanagement" \
      -H "X-Api-Key: ${SONARR_API_KEYS[$i]}" \
      -H "Content-Type: application/json" \
      -d "$media_management_json"
  done
}

# Change the NamingConfig for Radarr
change_radarr_naming_config() {
  local naming_json='{
    "id": 1,
    "renameMovies": true,
    "replaceIllegalCharacters": true,
    "colonReplacementFormat": "delete",
    "standardMovieFormat": "{Movie Title:DE}{(Release Year)} [tmdb-{TmdbId}] - {Edition Tags }{[Custom Formats]}{[Quality Full]}{[MediaInfo 3D]}{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[Mediainfo VideoCodec]}{-Release Group}",
    "movieFolderFormat": "{Movie Title:DE} ({Release Year}) {tmdb-{TmdbId}}"
  }'

  for i in "${!RADARR_URLS[@]}"; do
    curl -X PUT "${RADARR_URLS[$i]}/api/v3/config/naming" \
      -H "X-Api-Key: ${RADARR_API_KEYS[$i]}" \
      -H "Content-Type: application/json" \
      -d "$naming_json"
  done
}

# Change the MediaManagementConfig for Radarr
change_radarr_mediamanagement_config() {
  local media_management_json='{
    "id": 1,
    "autoUnmonitorPreviouslyDownloadedMovies": false,
    "recycleBinCleanupDays": 7,
    "downloadPropersAndRepacks": "doNotPrefer",
    "createEmptyMovieFolders": false,
    "deleteEmptyFolders": false,
    "fileDate": "1",
    "rescanAfterRefresh": "always",
    "autoRenameFolders": true,
    "pathsDefaultStatic": true,
    "setPermissionsLinux": false,
    "chmodFolder": "",
    "chownGroup": "",
    "skipFreeSpaceCheckWhenImporting": false,
    "minimumFreeSpaceWhenImporting": 100,
    "copyUsingHardlinks": false,
    "useScriptImport": false,
    "importExtraFiles": true,
    "extraFileExtensions": "srt,sub,idx,vob,nfo",
    "enableMediaInfo": true
  }'

  for i in "${!RADARR_URLS[@]}"; do
    curl -X PUT "${RADARR_URLS[$i]}/api/v3/config/mediamanagement" \
      -H "X-Api-Key: ${RADARR_API_KEYS[$i]}" \
      -H "Content-Type: application/json" \
      -d "$media_management_json"
  done
}

change_sonarr_naming_config
change_sonarr_mediamanagement_config

change_radarr_naming_config
change_radarr_mediamanagement_config

echo "Configurations for Sonarr and Radarr have been updated."