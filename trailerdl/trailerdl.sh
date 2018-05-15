#!/bin/bash
#################################
#Search this paths
PATHS=( "/mnt/omv1/omv1/filme" "/mnt/omv2/omv2/filme" "/mnt/omv3/omv3/filme" "/mnt/omv4/omv4/filme" )
#Base Url for video download
YTB_URL="https://www.youtube.com/watch?v="
#################################

rm trailerdl.log &>/dev/null

downloadTrailer(){
        youtube-dl -f $Q "$YTB_URL$ID" -o "$DIR/$FILENAME-trailer.%(ext)s" |& tee -a trailerdl.log
}

for i in "${PATHS[@]}"
do
        find $i -mindepth 1 -maxdepth 2 -type d '!' -exec sh -c 'ls -1 "{}"|egrep -i -q "trailer\.(mp4|avi|mkv)$"' ';' -print | while read DIR
        do
                MOVIE=$(echo "$DIR" | awk -F'[/]' '{print $6}')
                FILENAME=$(ls "$DIR" | egrep '\.nfo$' | sed s/".nfo"//g)

                if ! [ -z "$FILENAME" ]; then
                        ID=$(awk -F "[><]" '/trailer/{print $3}' "$DIR/$FILENAME.nfo" | awk -F'[=&]' '{print $4}' | awk -F'[ ]' '{print $1}')
                        ID=$(echo $ID | while read -a array; do echo "${array[0]}" ; done)
                        echo |& tee -a trailerdl.log
                        echo "Movie: $i/$MOVIE" |& tee -a trailerdl.log
                        echo "Filename: $FILENAME" |& tee -a trailerdl.log
                        echo "YoutubeID: $ID" |& tee -a trailerdl.log
                        if ! [ -z "$ID" ]; then

                                CHECK=$(youtube-dl -F "$YTB_URL$ID")
                                HD=$(echo "$CHECK" | grep "22 ")
                                SD=$(echo "$CHECK" | grep "18 ")

                                if ! [ -z "$HD" ]; then
                                        echo "Quality: 720p available" |& tee -a trailerdl.log
                                        Q=22
                                        downloadTrailer

                                elif ! [ -z "$SD" ]; then
                                        echo "Quality: SD available" |& tee -a trailerdl.log
                                        Q=18
                                        downloadTrailer

                                else
                                        echo "ERROR: Could not download the video"
                                fi

                        fi
                fi
        done
done
