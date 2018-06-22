#!/bin/bash
avr_mac="00:05:cd:36:5b:6e"
avr_ip="192.168.2.244"
BD_mac="00:c2:c6:ca:2f:79"
BD_ip="192.168.2.245"
SATCBL_mac="f8:da:0c:a0:d1:97"
SATCBL_ip="192.168.2.247"

loop_sleep_timer=2s
effect="Rainbow swirl fast"

# Loop
while true
do

        sleep "$loop_sleep_timer"

        echo "Ping $avr_ip"
        ping_avr=$(ping "$avr_ip" -c 1 | grep "1 received")
        hyperion_status=$(service hyperion status | grep running)

        # Hyperion status
        if [ -z "$hyperion_status" ]; then
                echo "Hyperion is not running. Starting Hyperion."
                sudo service hyperion start
                sleep 2s
                hyperion-remote -p 11 --effect "$effect"
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

                if ! [ "$avr_input" = "$avr_status" ]; then
                        avr_status="$avr_input"
                        echo "Active input: $avr_input"
                fi

                # BD input
                if [ "$avr_input" = "BD" ]; then

                        echo "Ping $BD_ip"
                        ping=$(ping "$BD_ip" -c 1 | grep "1 received")

                        if ! [ -z "$ping" ]; then

                                unset pingeffect

                                if ! [ "${hyperion_prio[0]}" = "10" ]; then
                                        echo "$avr_input: Give priority to Ambilight"
                                        hyperion-remote -p 2 --clear
                                        hyperion-remote -p 3 --clear
                                fi

                        elif [ -z "$pingeffect" ]; then

                                echo "$avr_input: Not reachable. Set effect."
                                pingeffect=true
                                hyperion-remote -p 2 --effect "$effect"

                        fi

                # SAT/CBL input
                elif [ "$avr_input" = "SAT/CBL" ]; then

                        echo "Ping $SATCBL_ip"
                        ping=$(ping "$SATCBL_ip" -c 1 | grep "1 received")

                        if ! [ -z "$ping" ]; then

                                unset pingeffect

                                if ! [ "${hyperion_prio[0]}" = "3" ]; then
                                        if [ "${hyperion_prio[0]}" = "2" ]; then
                                                echo "$avr_input: Clear ping effect"
                                                hyperion-remote -p 2 --clear
                                        fi
                                        echo "$avr_input: Set color"
                                        hyperion-remote -p 3 -c blue
                                fi

                        elif [ -z "$pingeffect" ]; then

                                echo "$input: Not reachable. Set effect."
                                pingeffect=true
                                hyperion-remote -p 2 --effect "$effect"

                        fi

                # All other inputs
                elif ! [ "${hyperion_prio[0]}" = "2" ]; then
                        echo "No defined input. Clear priorities."
                        hyperion-remote -p 3 --clear
                        hyperion-remote -p 2 --effect "Knight rider"
                fi

        else
                unset pingeffect

                avr_status="Offline"
                echo "$avr_status"
                if ! [ "${hyperion_prio[0]}" = "11" ]; then
                        echo "Set fallback effect"
                        hyperion-remote --clearall
                        hyperion-remote -p 11 --effect "$effect"
                fi
        fi

done