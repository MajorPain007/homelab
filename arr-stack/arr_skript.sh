#!/bin/bash

# This script is designed to update the quality definitions and various configuration settings for the applications Sonarr and Radarr.
# These applications are used to manage TV shows and movies, automate downloads, and organize libraries.

# Prerequisites for the script:
# - curl: A tool to send HTTP requests.
# - jq: A command-line tool for processing JSON data.
# Both can be installed via the package manager if needed (e.g., "sudo apt-get install curl jq").

# Define the base URLs and API keys for connecting to Sonarr and Radarr services on the local network.
SONARR_URLS=("http://192.168.178.:8989") # ("http://url-sonarr:8989" "http://andere-url-sonarr:8989")
SONARR_API_KEYS=("") # ("sonarr_api_key_1" "sonarr_api_key_2")

# Arrays for Radarr
RADARR_URLS=("http://192.168.178.:7878") # ("http://url-radarr:7878" "http://andere-url-radarr:7878")
RADARR_API_KEYS=("") # ("radarr_api_key_1" "radarr_api_key_2")

# Quality definitions for Sonarr in JSON format.
# It defines minimum, maximum, and preferred file sizes for different video quality levels.
sonarr_quality_definitions='{
  "HDTV-720p": {"minSize": 10, "maxSize": 1000, "preferredSize": 999},
  "WEBDL-720p": {"minSize": 10, "maxSize": 1000, "preferredSize": 999},
  "WEBRip-720p": {"minSize": 10, "maxSize": 1000, "preferredSize": 999},
  "Bluray-720p": {"minSize": 17.1, "maxSize": 1000, "preferredSize": 999},
  "HDTV-1080p": {"minSize": 15, "maxSize": 1000, "preferredSize": 999},
  "WEBDL-1080p": {"minSize": 15, "maxSize": 1000, "preferredSize": 999},
  "WEBRip-1080p": {"minSize": 15, "maxSize": 1000, "preferredSize": 999},
  "Bluray-1080p": {"minSize": 50.4, "maxSize": 1000, "preferredSize": 999},
  "Bluray-1080p Remux": {"minSize": 69.1, "maxSize": 1000, "preferredSize": 999},
  "HDTV-2160p": {"minSize": 25, "maxSize": 1000, "preferredSize": 999},
  "WEBDL-2160p": {"minSize": 25, "maxSize": 1000, "preferredSize": 999},
  "WEBRip-2160p": {"minSize": 25, "maxSize": 1000, "preferredSize": 999},
  "Bluray-2160p": {"minSize": 94.6, "maxSize": 1000, "preferredSize": 999},
  "Bluray-2160p Remux": {"minSize": 187.4, "maxSize": 1000, "preferredSize": 999}
}'

# Quality definitions for Radarr in JSON format.
# Similar format to Sonarr settings, but with different size standards.
radarr_quality_definitions='{
  "HDTV-720p": {"minSize": 17.1, "maxSize": 2000, "preferredSize": 1999},
  "WEBDL-720p": {"minSize": 12.5, "maxSize": 2000, "preferredSize": 1999},
  "WEBRip-720p": {"minSize": 12.5, "maxSize": 2000, "preferredSize": 1999},
  "Bluray-720p": {"minSize": 25.7, "maxSize": 2000, "preferredSize": 1999},
  "HDTV-1080p": {"minSize": 33.8, "maxSize": 2000, "preferredSize": 1999},
  "WEBDL-1080p": {"minSize": 12.5, "maxSize": 2000, "preferredSize": 1999},
  "WEBRip-1080p": {"minSize": 12.5, "maxSize": 2000, "preferredSize": 1999},
  "Bluray-1080p": {"minSize": 50.8, "maxSize": 2000, "preferredSize": 1999},
  "Remux-1080p": {"minSize": 102, "maxSize": 2000, "preferredSize": 1999},
  "HDTV-2160p": {"minSize": 85, "maxSize": 20000, "preferredSize": 1999},
  "WEBDL-2160p": {"minSize": 34.5, "maxSize": 20000, "preferredSize": 1999},
  "WEBRip-2160p": {"minSize": 34.5, "maxSize": 20000, "preferredSize": 1999},
  "Bluray-2160p": {"minSize": 102, "maxSize": 2000, "preferredSize": 1999},
  "Remux-2160p": {"minSize": 187.4, "maxSize": 20000, "preferredSize": 1999}
}'

# Function: update_quality_definitions
# Purpose: This function updates the quality definitions of Sonarr and Radarr based on the predefined values.
# It connects to the server via the API, retrieves the current definitions, checks them, and updates them if necessary.
update_quality_definitions() {
  local api_urls=$1
  local api_keys=$2
  local quality_definitions=$3

  # Iterate through all URLs and their associated API keys.
  for i in "${!api_urls[@]}"; do
    local api_url="${api_urls[$i]}"
    local api_key="${api_keys[$i]}"

    echo "Connecting to the server at $api_url... Retrieving quality definitions."

    # Retrieve the current quality definitions with a GET request and store the response.
    response=$(curl -s -H "X-Api-Key: $api_key" "$api_url/api/v3/qualitydefinition")

    # Check if the response is valid JSON, otherwise output an error message.
    if ! echo "$response" | jq . >/dev/null 2>&1; then
      echo "Error: Invalid JSON response from the API."
      return
    fi

    echo "Received quality definitions:"
    echo "$response" | jq -r '.[].quality.name'

    # Process each quality definition.
    echo "$response" | jq -c '.[]' | while read -r current_definition; do
      quality_name=$(echo "$current_definition" | jq -r '.quality.name')
      id=$(echo "$current_definition" | jq -r '.id')

      echo "Processing: $quality_name, ID: $id"

      # Get the new definition based on the name, if available.
      new_definition=$(echo "$quality_definitions" | jq --arg name "$quality_name" '.[$name] // empty')

      # Check if a new definition is available and update the values.
      if [ -n "$new_definition" ]; then
        new_minSize=$(echo "$new_definition" | jq '.minSize')
        new_maxSize=$(echo "$new_definition" | jq '.maxSize')
        new_preferredSize=$(echo "$new_definition" | jq '.preferredSize')

        # Update the current JSON definition with the new values.
        updated_definition=$(echo "$current_definition" | jq --argjson newMinSize "$new_minSize" \
          --argjson newMaxSize "$new_maxSize" \
          --argjson newPreferredSize "$new_preferredSize" \
          '.minSize = $newMinSize | .maxSize = $newMaxSize | .preferredSize = $newPreferredSize')

        echo "Updated definition: $updated_definition"

        # Send the updated definition to the server with a PUT request and output the result.
        curl_response=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$api_url/api/v3/qualitydefinition/$id" \
          -H "X-Api-Key: $api_key" \
          -H "Content-Type: application/json" \
          -d "$updated_definition")

        # Report the success or failure of the update.
        if [ "$curl_response" -eq 200 ] || [ "$curl_response" -eq 200  ]; then
          echo "Successfully updated: $quality_name"
        else
          echo "Error updating $quality_name, HTTP status: $curl_response"
        fi
      else
        echo "No matching definition found for $quality_name."
      fi
    done
  done
}

# Function: change_config
# Purpose: This generic function changes configuration settings for Sonarr or Radarr based on a provided JSON object.
change_config() {
  local api_urls=$1
  local api_keys=$2
  local config_endpoint=$3
  local config_json=$4

  # Iterate through the API URLs and update the configuration for each service.
  for i in "${!api_urls[@]}"; do
    curl -X PUT "${api_urls[$i]}/api/v3/$config_endpoint" \
      -H "X-Api-Key: ${api_keys[$i]}" \
      -H "Content-Type: application/json" \
      -d "$config_json"
  done
}

# Function: change_sonarr_naming_config
# Purpose: Changes the naming configurations for Sonarr.
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
  change_config "${SONARR_URLS[@]}" "${SONARR_API_KEYS[@]}" "config/naming" "$naming_json"
}

# Function: change_sonarr_mediamanagement_config
# Purpose: Updates the media management settings in Sonarr.
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
  change_config "${SONARR_URLS[@]}" "${SONARR_API_KEYS[@]}" "config/mediamanagement" "$media_management_json"
}

# Function: change_radarr_naming_config
# Purpose: Configures the naming options for Radarr.
change_radarr_naming_config() {
  local naming_json='{
    "id": 1,
    "renameMovies": true,
    "replaceIllegalCharacters": true,
    "colonReplacementFormat": "delete",
    "standardMovieFormat": "{Movie Title:DE}{(Release Year)} [tmdb-{TmdbId}] - {Edition Tags }{[Custom Formats]}{[Quality Full]}{[MediaInfo 3D]}{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[Mediainfo VideoCodec]}{-Release Group}",
    "movieFolderFormat": "{Movie Title:DE} ({Release Year}) {tmdb-{TmdbId}}"
  }'
  change_config "${RADARR_URLS[@]}" "${RADARR_API_KEYS[@]}" "config/naming" "$naming_json"
}

# Function: change_radarr_mediamanagement_config
# Purpose: Alters the media management settings in Radarr.
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
  change_config "${RADARR_URLS[@]}" "${RADARR_API_KEYS[@]}" "config/mediamanagement" "$media_management_json"
}

# Start of the script: Calls the functions for Sonarr and Radarr respectively
# to update the quality definitions and other configurations.
update_quality_definitions "${SONARR_URLS[@]}" "${SONARR_API_KEYS[@]}" "$sonarr_quality_definitions"
change_sonarr_naming_config
change_sonarr_mediamanagement_config

update_quality_definitions "${RADARR_URLS[@]}" "${RADARR_API_KEYS[@]}" "$radarr_quality_definitions"
change_radarr_naming_config
change_radarr_mediamanagement_config

# Output that the configurations have been successfully updated.
echo "Configurations for Sonarr and Radarr have been updated."