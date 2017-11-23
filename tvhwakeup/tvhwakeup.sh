#!/bin/sh
logger "Running TVH Recording Wake-Up Script"

# Default wake up time based on the day
sys_start_mo=12:00:00
sys_start_tu=12:00:00
sys_start_we=12:00:00
sys_start_th=09:00:00
sys_start_fr=09:00:00
sys_start_sa=08:00:00
sys_start_su=08:00:00

#check intervall
loop_sleep_timer=15m

#tv headend connection
tvh_user=kodi
tvh_password=kodi
tvh_host=localhost
tvh_port=9981

# Loop
while true
do     
    # Set the default wake up time based on the weekday 
    today=$(date -d'today' +'%a')
    monday=$(date -d'monday' +'%a')
    tuesday=$(date -d'tuesday' +'%a')
    wednesday=$(date -d'wednesday' +'%a')
    thursday=$(date -d'thursday' +'%a')
    friday=$(date -d'friday' +'%a')
    saturday=$(date -d'saturday' +'%a')
    sunday=$(date -d'sunday' +'%a')
    
    if [ "$today" = "$monday" ]; then
        wake_today=$sys_start_mo
        wake_tomorrow=$sys_start_tu
    elif [ "$today" = "$tuesday" ]; then
        wake_today=$sys_start_tu
        wake_tomorrow=$sys_start_we
    elif [ "$today" = "$wednesday" ]; then
        wake_today=$sys_start_we
        wake_tomorrow=$sys_start_th
    elif [ "$today" = "$thursday" ]; then
        wake_today=$sys_start_th
        wake_tomorrow=$sys_start_fr
    elif [ "$today" = "$friday" ]; then
        wake_today=$sys_start_fr
        wake_tomorrow=$sys_start_sa
    elif [ "$today" = "$saturday" ]; then
        wake_today=$sys_start_sa
        wake_tomorrow=$sys_start_su
    elif [ "$today" = "$sunday" ]; then
        wake_today=$sys_start_su
        wake_tomorrow=$sys_start_mo
    fi

    # Check to see if the default wake up time for today is already in the past and set it for today or tomorrow
    wake_today_seconds=$(date -d "today ${wake_today}" +%s)
    wake_tomorrow_seconds=$(date -d "tomorrow ${wake_tomorrow}" +%s)    
    current_time_seconds=$(date +%s)

    if [ "$current_time_seconds" -gt "$wake_today_seconds" ]; then
      default_wake=$wake_tomorrow_seconds
    else
      default_wake=$wake_today_seconds
    fi

    default_wake_converted=$(date --date=@"$default_wake")
    logger "TVH WakeUp: Next default wake up time is $default_wake_converted"

    # Get next scheduled recording time
    next_recording=$(curl -s http://"$tvh_user":"$tvh_password"@"$tvh_host":"$tvh_port"/api/dvr/entry/grid_upcoming | tr , '\n' | grep start_real | sed "s/.*start_real.:\([0-9]*\).*/\1/" | sort -n | head -1)
    next_recording_converted=$(date -d @"$next_recording")
 
    if [ "$next_recording" = "" ]; then
        logger "TVH WakeUp: No recordings scheduled."
        wake=""     
    else
        wake=$((next_recording-300))
        wake_converted=$(date -d @$wake)
        logger "TVH WakeUp: Next recording is scheduled at $next_recording_converted - Timestamp $next_recording"
    fi

    # Check if a recording is scheduled before the server is alive
    if [ "$wake" = "" ]; then
        rtc_wake=$default_wake
        logger "TVH WakeUp: No recording found. Use default waking time at $default_wake_converted"
    elif [ "$default_wake" -lt "$wake" ]; then
        rtc_wake=$default_wake
        logger "TVH WakeUp: Found scheduled recording is after the next default wake up time. Use default waking time at $default_wake_converted"
    else
        rtc_wake=$wake
        logger "TVH WakeUp: Found scheduled recording is before the next default wake up time. Set waking time at $wake_converted"
    fi

    # Set next required wake up time
    /usr/bin/sudo /usr/sbin/rtcwake -l -m no -t $rtc_wake

    #Sleep
    logger "TVH WakeUp: Wait $loop_sleep_timer for the next check"
    sleep $loop_sleep_timer

done
