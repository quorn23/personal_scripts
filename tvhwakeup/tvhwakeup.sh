#!/bin/sh
logger "Running TVH Recording Wake-Up Script"

# Settings
default_wake=10:00:00
loop_sleep_timer=15m
tvh_user=kodi
tvh_password=kodi
tvh_host=localhost
tvh_port=9981

# Loop
while true
do

    # Default wake up time - Check to see if the default wake up time for today is already in the past and set it for today or tomorrow
    current_time=`date +%s`
    wake_today=`date -d "today ${default_wake}" +%s`
    wake_tomorrow=`date -d "tomorrow ${default_wake}" +%s`

    if [ $current_time -gt $wake_today ]; then
      default_wake=$wake_tomorrow
    else
      default_wake=$wake_today
    fi

    default_wake_converted=`date --date=@$default_wake`
    logger "TVH WakeUp: Default wake up time is $default_wake_converted"

    # Get next scheduled recording time
    next_recording=`curl -s http://"$tvh_user":"$tvh_password"@"$tvh_host":"$tvh_port"/api/dvr/entry/grid_upcoming | tr , '\n' | grep start_real | sed "s/.*start_real.:\([0-9]*\).*/\1/" | sort -n | head -1`
    next_recording_converted=`date -d @$next_recording`
 
    if [ "$next_recording" = "" ]; then
        logger "TVH WakeUp: No recordings scheduled."
    else
        wake=$((next_recording-300))
        wake_converted=`date -d @$wake`
        logger "TVH WakeUp: Next recording is scheduled at $next_recording_converted - Timestamp $next_recording"
    fi

    # Check if a recording is scheduled before the server is alive
    if [ $default_wake -lt $wake ]; then
        rtc_wake=$default_wake
        logger "TVH WakeUp: Default wake up time is earlier than the next scheduled recording. Use default waking time at $default_wake_converted"
    else
        rtc_wake=$wake
        logger "TVH WakeUp: Found scheduled recording before the server is going to start. Set waking time at $wake_converted"
    fi

    # Set next required wake up time
    /usr/bin/sudo /usr/sbin/rtcwake -l -m no -t $rtc_wake

    #Sleep
    logger "TVH WakeUp: Wait $loop_sleep_timer for the next check"
    sleep $loop_sleep_timer

done
