
#!/bin/sh
WATCHED_MOVIE_FOLDER="/mnt/omv1/omv1/downloads/filme/"
WATCHED_SHOW_FOLDER="/mnt/omv1/omv1/downloads/serien/"
MOVIE_DOWNLOAD_FOLDER="/mnt/omv1/omv1/downloads/filme"
SHOW_DOWNLOAD_FOLDER="/mnt/omv1/omv1/downloads/serien"
MOVIE_TEMP_FOLDER="/mnt/omv1/omv1/downloads/unsorted/filme"
SHOW_TEMP_FOLDER="/mnt/omv1/omv1/downloads/unsorted/serien"
LOG="/mnt/omv1/scripts/watchdog.log"
FILEBOT_EXCLUDE="/mnt/omv1/scripts/amc.txt"
MOVIE_TARGET_FILENAMEANDPATH="/mnt/omv3/omv3/filme/{n.ascii()} ({y})/{n.ascii()} ({y}) {vf} {fn =~ /3D/ ? ' 3D '+s3d : ''}{fn =~ /3d/ ? ' 3D '+s3d : ''}{' CD'+pi}"

##log function
log() {
        logger "Filebot Watchdog: $1"
        echo $1 >> $LOG
        echo $1
}

##delete old logs
rm $LOG >/dev/null 2>&1

log > echo "$(date +%Y-%m-%d:%H:%M:%S) Watchdog started"

monitor_movies() {

        inotifywait -m -q -e create -e delete -r --exclude '\.part$' --format %f "$1" | while read file
        do

        MOVIEARCHIVES=$(find $MOVIE_DOWNLOAD_FOLDER -print | grep -c -i -E '\.rar$|\.r00$|\.part$|\.zip$' 2> /dev/null)
        MOVIESFOUND=$(find $MOVIE_DOWNLOAD_FOLDER -print | grep -c -i -E '\.mkv$|\.avi$|\.mp4$' 2> /dev/null)

        if [ "$MOVIEARCHIVES" != "0" ]
        then
                log > echo "$(date +%Y-%m-%d:%H:%M:%S) Movie archives found. Skip."
        else
                if [ "$MOVIESFOUND" != "0" ]
                then
                        log > echo "$(date +%Y-%m-%d:%H:%M:%S) New movies found. Moving files."
                        mkdir -p $MOVIE_TEMP_FOLDER >/dev/null 2>&1
                        mv $MOVIE_DOWNLOAD_FOLDER/* $MOVIE_TEMP_FOLDER >/dev/null 2>&1
                fi
        fi

        FILEBOTMOVIES=$(find $MOVIE_TEMP_FOLDER -print | grep -c -i -E '\.mkv$|\.avi$|\.mp4$' 2> /dev/null)

        if [ "$FILEBOTMOVIES" != "0" ]
        then
                log > echo "$(date +%Y-%m-%d:%H:%M:%S) Running Filebot"
                filebot -script fn:amc --lang de --conflict override --log-file $LOG --action move -non-strict "$MOVIE_TEMP_FOLDER" --def "movieFormat=$MOVIE_TARGET_FILENAMEANDPATH" --def unsorted=n --def artwork=n --def excludeList=$FILEBOT_EXCLUDE --def skipExtract=y --def ut_label=MOVIE
                filebot -script fn:cleaner "$MOVIE_TEMP_FOLDER" --def root=n
        fi

        done
}

monitor_shows() {

        inotifywait -m -q -e create -e delete -r --exclude '\.part$' --format %f "$1" | while read file
        do

        EPISODEARCHIVES=$(find $SHOW_DOWNLOAD_FOLDER -print | grep -c -i -E '\.rar$|\.r00$|\.part$|\.zip$' 2> /dev/null)
        EPISODESFOUND=$(find $SHOW_DOWNLOAD_FOLDER -print | grep -c -i -E '\.mkv$|\.avi$|\.mp4$' 2> /dev/null)

        if [ "$EPISODEARCHIVES" != "0" ]
        then
                log > echo "$(date +%Y-%m-%d:%H:%M:%S) Episode archives found. Skip."
        else
                if [ "$EPISODESFOUND" != "0" ]
                then
                        log > echo "$(date +%Y-%m-%d:%H:%M:%S) New episodes found. Moving files."
                        mkdir -p $SHOW_TEMP_FOLDER >/dev/null 2>&1
                        mv $SHOW_DOWNLOAD_FOLDER/* $SHOW_TEMP_FOLDER >/dev/null 2>&1
                fi
        fi

        done
}

monitor_movies $WATCHED_MOVIE_FOLDER &
monitor_shows $WATCHED_SHOW_FOLDER




