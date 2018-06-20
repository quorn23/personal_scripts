#!/bin/bash
check_ip=('192.168.2.248')
wol_mac=('70:85:c2:02:c6:31')
loop_sleep_timer=5s

# Loop
while true
do

        unset found_client
        unset ping_client
        unset ping_target

        hyperion_status=$(service hyperion status | grep running)

        # Check if client IPs are online
        for client in "${check_ip[@]}"
        do
                ping_client=$(ping "$client" -c 1 | grep "1 received")
                if ! [ -z "$ping_client" ]; then

                        found_client="$client"

                        # Start Hyperion
                        if [ -z "$hyperion_status" ]; then
                                echo "Client $client found and Hyperion is not running. Starting Hyperion."
                                sudo service hyperion start
                        fi

                        break

                fi
        done


        # Stop Hyperion if no client is reachable
        if [ -z "$found_client" ] && ! [ -z "$hyperion_status" ]; then
                echo "Clients are offline and Hyperion is still running. Stopping Hyperion."
                sudo service hyperion stop
        fi


        # Wake all required devices as soon as one client IP has been found
        if ! [ -z "$found_client" ]; then
                for wake_target in "${wol_mac[@]}"
                do
                        # Ping target to check if it's already online
                        wake_ip=$(arp | grep "$wake_target" | awk ' { print $1 } ')
                        ping_target=$(ping "$wake_ip" -c 1 | grep "1 received")

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