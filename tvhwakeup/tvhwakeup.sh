
#!/bin/sh
logger "Running TVH Recording Wake-Up Script"

# Usual daily wake up time
default_wake_at=10:00:00
loop_sleep_timer=15m

# Check  to see if the wake up for today is already in the past
current_time=`date +%s`
wake_today=`date -d "today ${default_wake_at}" +%s`
wake_tomorrow=`date -d "tomorrow ${default_wake_at}" +%s`

if [ $current_time -gt $wake_today ]; then
  default_wake_at=$wake_tomorrow
else
  default_wake_at=$wake_today
fi

default_wake_at_converted=`date --date=@$default_wake_at`
logger "TVH WakeUp: Next planned default wake up is $default_wake_at_converted"
/usr/bin/sudo /usr/sbin/rtcwake -l -m no -t $default_wake_at

# Loop to scan for new scheduled recordings
while true
do
    next_recording=`curl -s http://kodi:kodi@localhost:9981/api/dvr/entry/grid_upcoming | tr , '\n' | grep start_real | sed "s/.*start_real.:\([0-9]*\).*/\1/" | sort -n | head -1`
    next_recording_converted=`date -d @$next_recording`

    if [ "$next_recording" = "" ]; then
        logger "TVH WakeUp: No recordings scheduled."
    else
        wake_at=$((next_recording-300))
        wake_at_converted=`date -d @$wake_at`
        logger "TVH WakeUp: Next recording is scheduled at $next_recording_converted - Timestamp $next_recording"
    fi

    if [ $default_wake_at -lt $wake_at ]; then
        rtc_wake=$default_wake_at
        logger "TVH WakeUp: Default wake up time is earlier than the next scheduled recording. Set default waking time at $default_wake_at_converted"
    else
        rtc_wake=$wake_at
        logger "TVH WakeUp: Found scheduled recording before the server is going to start. Set waking time at $wake_at_converted"
    fi

/usr/bin/sudo /usr/sbin/rtcwake -l -m no -t $rtc_wake

logger "TVH WakeUp: Wait for $loop_sleep_timer for the next recording check"

sleep $loop_sleep_timer

done
