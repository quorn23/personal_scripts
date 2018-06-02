#!/bin/bash
#################################
#Search this paths
PATHS=( "/mnt/omv1/omv1/filme" "/mnt/omv2/omv2/filme" "/mnt/omv3/omv3/filme" "/mnt/omv4/omv4/filme" )
#Base Url for video download
YTB_URL="https://www.youtube.com/watch?v="
#TheMovieDB API
API=
#Language Code
LANG=$1
if [ -z "$LANG" ]; then
        LANG=de
fi
#################################

rm trailerdl.log &>/dev/null

downloadTrailer(){
        youtube-dl -f mp4 "$YTB_URL$ID" -o "$DIR/$FILENAME-trailer.%(ext)s" --restrict-filenames |& tee -a trailerdl.log
}

log(){
        echo "$1" |& tee -a trailerdl.log
}

for i in "${PATHS[@]}"
do
        find $i -mindepth 1 -maxdepth 2 -type d '!' -exec sh -c 'ls -1 "{}"|egrep -i -q "trailer\.(mp4|avi|mkv)$"' ';' -print | while read DIR
        do
                FILENAME=$(ls "$DIR" | egrep '\.nfo$' | sed s/".nfo"//g)

                if ! [ -z "$FILENAME" ]; then

                        #Get TheMovieDB ID from NFO
                        TMDBID=$(awk -F "[><]" '/tmdbid/{print $3}' "$DIR/$FILENAME.nfo" | awk -F'[ ]' '{print $1}')

                        #Get trailer YouTube ID
                        JSON=($(curl -s "http://api.themoviedb.org/3/movie/"$TMDBID"/videos?api_key="$API"&language="$LANG | jq -r '.results[] | select(.type=="Trailer") | .key'))
                        ID="${JSON[0]}"

                        log ""
                        log "Movie Path: $DIR"
                        log "Processing file: $FILENAME.nfo"
                        log "TheMovieDB ID: $TMDBID"
                        log "YouTube ID: $ID"

                        if ! [ -z "$ID" ]; then
                                log "Downloading: $YTB_URL$ID"
                                downloadTrailer
                        fi

                fi
        done
done
