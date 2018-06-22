#!/bin/bash
avr_mac="00:05:CD:36:5B:6E"
avr_ip="192.168.2.244"
BD_mac="00:C2:C6:CA:2F:79"
SATCBL_mac="F8:DA:0C:A0:D1:97"

loop_sleep_timer=2s
effect="Rainbow swirl fast"

# Loop
while true
do

        ping_avr=$(arp | grep "$avr_mac")
        #ping_avr=$(ping "$avr_ip" -c 1 | grep "1 received")
        hyperion_status=$(service hyperion status | grep running)

        # Hyperion status
        if [ -z "$hyperion_status" ]; then
                echo "Hyperion is not running. Starting Hyperion."
                sudo service hyperion start
        else
                hyperion_json=$(hyperion-remote -l | tail -n +7)
                hyperion_effect=$(echo "$hyperion_json" | jq '.activeEffects[]')
                hyperion_color=$(echo "$hyperion_json" | jq '.activeLedColor[]')
                hyperion_prio=($(echo "$hyperion_json" | jq '.priorities[].priority'))
        fi

        # If AVR is online
        if ! [ -z "$ping_avr" ] && [ "${hyperion_prio[0]}" = "1" ]; then

                echo "Custom lightning is set"

        elif ! [ -z "$ping_avr" ]; then

                avr_input=$(curl -s http://$avr_ip/goform/formMainZone_MainZoneXmlStatusLite.xml | grep InputFuncSelect | sed -n -e "s/.*<InputFuncSelect><value>\(.*\)<\/value><\/InputFuncSelect>.*/\1/p")

                echo "Active input: $avr_input"

                # BD input
                if [ "$avr_input" = "BD" ]; then

                        ping=$(arp | grep "$BD_mac")

                        if ! [ -z "$ping" ]; then

                                unset pingeffect

                                if [ "${hyperion_prio[0]}" = "10" ]; then
                                        echo "BD: Ambilight is active"
                                else
                                        if [ "${hyperion_prio[0]}" = "2" ]; then
                                                echo "BD: Clear ping effect"
                                                hyperion-remote -p 2 --clear
                                        fi
                                        if [ "${hyperion_prio[0]}" = "3" ]; then
                                                echo "BD: Clear color"
                                                hyperion-remote -p 3 --clear
                                        fi
                                fi

                        elif [ -z "$pingeffect" ]; then

                                echo "BD not reachable. Set effect."
                                pingeffect=true
                                hyperion-remote -p 2 --effect "$effect"

                        fi

                # SAT/CBL input
                elif [ "$avr_input" = "SAT/CBL" ]; then

                        ping=$(arp | grep "$SATCBL_mac")

                        if ! [ -z "$ping" ]; then

                                unset pingeffect

                                if [ "${hyperion_prio[0]}" = "3" ]; then
                                        echo "SAT/CBL: Color is set"
                                else
                                        if [ "${hyperion_prio[0]}" = "2" ]; then
                                                echo "SAT/CBL: Clear ping effect"
                                                hyperion-remote -p 2 --clear
                                        fi
                                        echo "SAT/CBL: Set color"
                                        hyperion-remote -p 3 -c blue
                                fi

                        elif [ -z "$pingeffect" ]; then

                                echo "SAT/CBL not reachable. Set effect."
                                pingeffect=true
                                hyperion-remote -p 2 --effect "$effect"

                        fi

                # All other inputs
                elif ! [ -z "$hyperion_color" ] || ! [ -z "$hyperion_effect" ] ; then
                        hyperion-remote --clearall
                        hyperion-remote -c black
                fi

        elif ! [ -z "$hyperion_color" ] || ! [ -z "$hyperion_effect" ] ; then
                hyperion-remote --clearall
                hyperion-remote -c black
        fi

        # Wait for the next round
        sleep "$loop_sleep_timer"
done