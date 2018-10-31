#!/bin/bash

#################################
#            Config             #
#################################

#Search this paths (required)
#PATHS=( "/mnt/omv1/omv1/filme" "/mnt/omv2/omv2/filme" "/mnt/omv3/omv3/filme" "/mnt/omv4/omv4/filme" )
PATHS=( "/volume1/movies" )
#Your TheMovieDB API (required)
#Please visit https://developers.themoviedb.org/3 for more information
API=

#Language Code (required)
#Examples: de = German, en = English, etc.
LANGUAGE=en

#Custom path to store the log files. Uncomment this line and change the path. By default the working directory is going to be used.
#LOGPATH="/home/myexampleuser"

#################################

#Functions
downloadTrailer(){
        DL=$(youtube-dl -f mp4 "https://www.youtube.com/watch?v=$ID" -o "$DIR/$FILENAME-trailer.%(ext)s" --restrict-filenames)
        log "$DL"

        if [ -z "$(echo "$DL" | grep "100.0%")" ]; then
                missing ""
                missing "Error: Downloading failed - $FILENAME - $DIR - TheMovideDB: https://www.themoviedb.org/movie/$TMDBID - YouTube: https://www.youtube.com/watch?v=$ID"
                missing "------------------"
                missing "$DL"
                missing "------------------"
                missing ""
        else
                #Update file modification date
                touch "$DIR/$FILENAME-trailer.mp4"
        fi
}

log(){
        echo "$1" |& tee -a "$LOGPATH/trailerdl.log"
}

missing(){
        echo "$1" |& tee -a "$LOGPATH/trailerdl-error.log" &>/dev/null
}

#################################

#Delete old logs
rm "$LOGPATH/trailerdl.log" &>/dev/null
rm "$LOGPATH/trailerdl-error.log" &>/dev/null

#Use manually provided language code (optional)
if ! [ -z "$1" ]; then
        LANGUAGE="$1"
fi

#Use working directory for logs except a custom one is configured
if [ -z "$LOGPATH" ]; then
        LOGPATH=$(pwd)
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
