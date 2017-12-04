#!/bin/sh
logger "Running TVH Recording Wake-Up Script"

# Default wake up time based on the day
sys_start_mo=12:00:00
sys_start_tu=12:00:00
sys_start_we=12:00:00
sys_start_th=11:00:00
sys_start_fr=11:00:00
sys_start_sa=09:00:00
sys_start_su=09:00:00

#check intervall
loop_sleep_timer=15m

#tv headend connection
tvh_user=kodi
tvh_password=kodi
tvh_host=localhost
tvh_port=9981

#pushover integration
pushover_exec=/opt/scripts/pushover.sh

get_default_wake(){

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

    if [ "$current_time_seconds" -gt "$wake_today_seconds" ]; then
      default_wake=$wake_tomorrow_seconds
    else
      default_wake=$wake_today_seconds
    fi

    default_wake_converted=$(date --date=@"$default_wake")

}

get_recordings(){

    recordings=$(curl -s http://"$tvh_user":"$tvh_password"@"$tvh_host":"$tvh_port"/api/dvr/entry/grid_upcoming | tr , '\n' | grep start_real | sed "s/.*start_real.:\([0-9]*\).*/\1/" | sort -n)
    if ! [ "$recordings" = "" ]; then
        found_recordings=true
    else
        found_recordings=false
    fi

}

get_recording_time(){

    # Check for valid recordings
    for timestamp in $recordings 
    do
        timestamp_converted=$(date -d @$timestamp)
        timestamp_with_buffer=$((timestamp-180))

        if [ "$current_time_seconds" -gt "$timestamp_with_buffer" ]; then
            logger "TVH WakeUp: Found [$timestamp_converted - Timestamp $timestamp]"
            logger "TVH WakeUp: Recording already in progress or in the past. Skip."
        else
            if [ "$default_wake" -lt "$timestamp_with_buffer" ]; then
                rtc_wake=$default_wake
                logger "TVH WakeUp: Found [$timestamp_converted - Timestamp $timestamp]"
                logger "TVH WakeUp: Recording starts after the server has been booted up. Use default waking time."
            else
                rtc_wake=$timestamp_with_buffer
                logger "TVH WakeUp: Found [$timestamp_converted - Timestamp $timestamp]"
                logger "TVH WakeUp: Recording starts before the server has been booted up. Use it as waking time."
            fi
            break
        fi
    done

}

set_rtclock(){
    
    rtc_wake_current_converted=$(rtcwake -l -m show | sed s/"alarm: on  "//g)
    rtc_wake_current=$(date -d "${rtc_wake_current_converted}" +%s)
    rtc_wake_converted=$(date -d @$rtc_wake)    
    rtc_wake_difference=$(($rtc_wake_current-$rtc_wake))

    if  [ "$rtc_wake_difference" -gt "-20" ] && [ "$rtc_wake_difference" -lt "20" ]; then
        logger "TVH WakeUp: Boot is already correctly scheduled at $rtc_wake_current_converted"
    else
        logger "TVH WakeUp: Existing scheduled boot does not match. Set new waking time at $rtc_wake_converted"
        rtcwake -l -m no -t $rtc_wake
        if ! [ "$pushover_exec" == "" ]; then
             $pushover_exec -t "Boot" "Next scheduled auto boot is at $rtc_wake_converted"
        fi
    fi
}

# Loop
while true
do
    logger "### TVH WakeUp - Scan started ###"

    # Update current time variables
    today=$(date +'%u')
    current_time_seconds=$(date +%s)

    # Set the default wake up time based on the weekday
    get_default_wake
    logger "TVH WakeUp: Next default waking time is $default_wake_converted"

    # Get next scheduled recording time
    get_recordings

    # Check if recordings are scheduled
    logger "### TVH WakeUp - Check for recordings ###"
    if [ $found_recordings = true ]; then
        get_recording_time
    else
        logger "TVH WakeUp: No recordings found. Use default waking time."
        rtc_wake=$default_wake
    fi

    # Check the current set time and update it if required
    logger "### TVH WakeUp - Set wake up time ###"
    set_rtclock

    #Sleep
    logger "### TVH WakeUp - Wait $loop_sleep_timer ###"
    sleep $loop_sleep_timer

done
