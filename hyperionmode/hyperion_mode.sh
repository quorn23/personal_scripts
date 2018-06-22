#!/bin/bash
avr_mac="00:05:cd:36:5b:6e"
BD_mac="00:c2:c6:ca:2f:79"
SATCBL_mac="f8:da:0c:a0:d1:97"

loop_sleep_timer=2s
effect="Rainbow swirl fast"

# Loop
while true
do

        ping_avr=$(arp | grep "$avr_mac")
        avr_ip=$(echo "$ping_avr" | awk ' { print $1 } ')
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

                if [ -z "$custom_msg" ]; then
                        custom_msg=true
                        echo "Custom lightning is set"
                fi

        elif ! [ -z "$ping_avr" ]; then

                unset custom_msg

                avr_input=$(curl -s http://$avr_ip/goform/formMainZone_MainZoneXmlStatusLite.xml | grep InputFuncSelect | sed -n -e "s/.*<InputFuncSelect><value>\(.*\)<\/value><\/InputFuncSelect>.*/\1/p")

                if ! [ "$avr_input" = "$avr_previousinput" ]; then
                        avr_previousinput="$avr_input"
                        echo "Active input: $avr_input"
                fi

                # BD input
                if [ "$avr_input" = "BD" ]; then

                        input="BD"
                        ping=$(arp | grep "$BD_mac")

                        if ! [ -z "$ping" ]; then

                                unset pingeffect

                                if ! [ "${hyperion_prio[0]}" = "10" ]; then
                                        if [ "${hyperion_prio[0]}" = "2" ]; then
                                                echo "$input: Clear ping effect"
                                                hyperion-remote -p 2 --clear
                                        fi
                                        if [ "${hyperion_prio[0]}" = "3" ]; then
                                                echo "$input: Clear color"
                                                hyperion-remote -p 3 --clear
                                        fi
                                fi

                        elif [ -z "$pingeffect" ]; then

                                echo "$input: Not reachable. Set effect."
                                pingeffect=true
                                hyperion-remote -p 2 --effect "$effect"

                        fi

                # SAT/CBL input
                elif [ "$avr_input" = "SAT/CBL" ]; then

                        input="SAT/CBL"
                        ping=$(arp | grep "$SATCBL_mac")

                        if ! [ -z "$ping" ]; then

                                unset pingeffect

                                if ! [ "${hyperion_prio[0]}" = "3" ]; then
                                        if [ "${hyperion_prio[0]}" = "2" ]; then
                                                echo "$input: Clear ping effect"
                                                hyperion-remote -p 2 --clear
                                        fi
                                        echo "$input: Set color"
                                        hyperion-remote -p 3 -c blue
                                fi

                        elif [ -z "$pingeffect" ]; then

                                echo "$input: Not reachable. Set effect."
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