#!/bin/bash
check_mac=('00:C2:C6:CA:2F:79' 'B8:AE:ED:EB:07:03')
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
                #ping_client=$(ping "$client" -c 1 | grep "1 received")
                ping_client=$(arp | grep "$client")

                if ! [ -z "$ping_client" ]; then
                        found_client=$(arp | grep "$client" | awk ' { print $1 } ')
                        break
                fi
        done

        # Wake all required devices as soon as one client IP has been found
        if ! [ -z "$found_client" ]; then

                for wake_target in "${wol_mac[@]}"
                do
                        # Ping target to check if it's already online
                        #wake_ip=$(arp | grep "$wake_target" | awk ' { print $1 } ')
                        #ping_target=$(ping "$wake_ip" -c 1 | grep "1 received")
                        ping_target=$(arp | grep "$wake_target")

                        # Send WOL if required
                        if [ -z "$ping_target" ]; then
                                echo "Client $client found and $wake_ip is offline. Sending WOL signal."
                                sudo etherwake "$wake_target"
                                sleep 10s
                        fi
                done

        fi

        # Wait for the next round
        sleep "$loop_sleep_timer"
done