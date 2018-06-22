#!/bin/bash
check_mac=('00:c2:c6:ca:2f:79' 'b8:ae:ed:eb:07:03')
wol_mac=('70:85:c2:02:c6:31')
loop_sleep_timer=5s

# Loop
while true
do

        unset found_client
        unset ping_client
        unset ping_target

        # Check if client IPs are online
        for client in "${check_mac[@]}"
        do
                ping_client=$(arp | grep "$client")

                if ! [ -z "$ping_client" ]; then
                        found_client=$(echo "$ping_client" | awk ' { print $1 } ')
                        break
                fi
        done

        # Wake all required devices as soon as one client IP has been found
        if ! [ -z "$found_client" ]; then

                for wake_target in "${wol_mac[@]}"
                do
                        # Ping target to check if it's already online
                        ping_target=$(arp | grep "$wake_target")

                        # Send WOL if required
                        if [ -z "$ping_target" ]; then
                                echo "Client $found_client found and $ping_target is offline. Sending WOL signal."
                                sudo etherwake "$wake_target"
                                sleep 10s
                        fi
                done

        fi

        # Wait for the next round
        sleep "$loop_sleep_timer"
done