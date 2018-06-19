#!/bin/bash
#################################
#            Config             #
#################################

#Search this paths
PATHS=( "/mnt/omv1/omv1/filme" "/mnt/omv2/omv2/filme" "/mnt/omv3/omv3/filme" "/mnt/omv4/omv4/filme" )

#Your TheMovieDB API
API=

#Language Code
LANGUAGE=de

#################################

#Functions
downloadTrailer(){
        youtube-dl -f mp4 "https://www.youtube.com/watch?v=$ID" -o "$DIR/$FILENAME-trailer.%(ext)s" --restrict-filenames |& tee -a trailerdl.log
}

log(){
        echo "$1" |& tee -a trailerdl.log
}

missing(){
        echo "$1" |& tee -a trailerdl-missing.log &>/dev/null
}

#################################

#Delete old logs
rm trailerdl.log &>/dev/null
rm trailerdl-missing.log &>/dev/null

#Use manually provided language code (optional)
if ! [ -z "$1" ]; then
        LANGUAGE="$1"
fi

#Walk defined paths and search for movies without existing local trailer
for i in "${PATHS[@]}"
do
        find "$i" -mindepth 1 -maxdepth 2 -type d '!' -exec sh -c 'ls -1 "{}" | egrep -i -q "trailer\.(mp4|avi|mkv)$"' ';' -print | while read DIR
        do
                FILENAME=$(ls "$DIR" | egrep '\.nfo$' | sed s/".nfo"//g)

                if [ -f "$DIR/$FILENAME.nfo" ]; then

                        #Get TheMovieDB ID from NFO
                        TMDBID=$(awk -F "[><]" '/tmdbid/{print $3}' "$DIR/$FILENAME.nfo" | awk -F'[ ]' '{print $1}')

                        log ""
                        log "Movie Path: $DIR"
                        log "Processing file: $FILENAME.nfo"

                        if ! [ -z "$TMDBID" ]; then

                                log "TheMovieDB: https://www.themoviedb.org/movie/$TMDBID"

                                #Get trailer YouTube ID from themoviedb.org
                                JSON=($(curl -s "http://api.themoviedb.org/3/movie/$TMDBID/videos?api_key=$API&language=$LANGUAGE" | jq -r '.results[] | select(.type=="Trailer") | .key'))
                                ID="${JSON[0]}"

                                if ! [ -z "$ID" ]; then
                                                #Start download
                                        log "YouTube: https://www.youtube.com/watch?v=$ID"
                                        downloadTrailer

                                else
                                        log "YouTube: n/a"
                                        missing "Error: Missing YouTube ID - $FILENAME - $DIR - TheMovideDB: https://www.themoviedb.org/movie/$TMDBID"

                                fi

                        else
                                log "TheMovieDB: n/a"
                                missing "Error: Missing TheMovieDB ID - $FILENAME - $DIR"
                        fi

                fi
        done
done