#!/bin/sh
logger "Running TVH Recording Wake-Up Script"

# Default wake up time based on the day
sys_start_mo=12:00:00
sys_start_tu=12:00:00
sys_start_we=12:00:00
sys_start_th=10:00:00
sys_start_fr=10:00:00
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
    today=$(date +'%u')

    if [ "$today" = "1" ]; then
        wake_today=$sys_start_mo
        wake_tomorrow=$sys_start_tu
    elif [ "$today" = "2" ]; then
        wake_today=$sys_start_tu
        wake_tomorrow=$sys_start_we
    elif [ "$today" = "3" ]; then
        wake_today=$sys_start_we
        wake_tomorrow=$sys_start_th
    elif [ "$today" = "4" ]; then
        wake_today=$sys_start_th
        wake_tomorrow=$sys_start_fr
    elif [ "$today" = "5" ]; then
        wake_today=$sys_start_fr
        wake_tomorrow=$sys_start_sa
    elif [ "$today" = "6" ]; then
        wake_today=$sys_start_sa
        wake_tomorrow=$sys_start_su
    elif [ "$today" = "7" ]; then
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
    recordings=$(curl -s http://"$tvh_user":"$tvh_password"@"$tvh_host":"$tvh_port"/api/dvr/entry/grid_upcoming | tr , '\n' | grep start_real | sed "s/.*start_real.:\([0-9]*\).*/\1/" | sort -n)

    # Check if recordings are scheduled
    if [ "$recordings" = "" ]; then

        # no recordings found, use default wake up time
        logger "TVH WakeUp: No recording found. Use default waking time at $default_wake_converted"
        rtc_wake=$default_wake

    else

        # recordings found, select the one which is not already in progress
        for timestamp in $recordings
        do

            if [ "$current_time_seconds" -gt "$timestamp" ]; then
                # Recroding is already in progress
                next_recording_converted=$(date -d @$timestamp)
                logger "TVH WakeUp: Fetched recording is already in progress or in the past. ($next_recording_converted - $timestamp) "
            else
                # Recording is in the future
                next_recording=$timestamp
                next_recording_converted=$(date -d @$timestamp)
                wake=$((next_recording-300))
                wake_converted=$(date -d @$wake)
                logger "TVH WakeUp: Next valid recording is scheduled at $next_recording_converted - Timestamp $next_recording"
                break
            fi

        done

        # Compare recording timestamp against thedefault wake up time
        if [ "$default_wake" -lt "$wake" ]; then
            # Default wake up time is nearer in the future.
            rtc_wake=$default_wake
            logger "TVH WakeUp: The next scheduled recording is after the default wake up time. Use default waking time at $default_wake_converted"
        else
            # Recording is scheduled before the server has been started by the default setting.
            # Use the recording time and give the server 3 minutes more time to wake up.
            rtc_wake=$wake
            logger "TVH WakeUp: The next scheduled recording is before the default wake up time. Set waking time at $wake_converted"
        fi
    fi

    # Set next required wake up time
    /usr/bin/sudo /usr/sbin/rtcwake -l -m no -t $rtc_wake

    #Sleep
    logger "TVH WakeUp: Wait $loop_sleep_timer for the next check"
    sleep $loop_sleep_timer

done
