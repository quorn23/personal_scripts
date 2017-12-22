#!/bin/bash
check_ip=('192.168.2.1' '192.168.2.7')
wol_mac=('70:85:c2:02:c6:31')
loop_sleep_timer=10s

# Loop
while true
do
        # Check if client IPs are online
        for client in "${check_ip[@]}"
        do
                ping_result=$(ping "$client" -c 1 | grep Destination)
                if [ -z "$ping_result" ]; then
                        found_ip="$client"
                        break
                fi
        done

        # Wake all required devices as soon as one client IP has been found
        if ! [ -z "$found_ip" ]; then
                for wake_target in "${wol_mac[@]}"
                do
                        sudo etherwake "$wake_target"
                done
        fi

        # Wait for the next round
        sleep "$loop_sleep_timer"
done
