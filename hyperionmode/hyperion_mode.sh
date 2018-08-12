#!/bin/bash
avr_ip="192.168.2.16"
loop_sleep_timer=2s

# Loop
while true
do

	sleep "$loop_sleep_timer"

	ping_avr=$(ping "$avr_ip" -c 1 | grep "1 received")
	hyperion_status=$(service hyperion status | grep running)

	#Status
	if [ -z "$hyperion_status" ]; then
		echo "Hyperion is not running. Starting Hyperion."
		sudo service hyperion start
		sleep 2s
	else
		hyperion_json=$(hyperion-remote -l | tail -n +7)
		hyperion_prio=($(echo "$hyperion_json" | jq '.priorities[].priority'))
	fi

	if ! [ -z "$ping_avr" ] && [ "${hyperion_prio[0]}" = "1" ]; then

		if ! [ "$is_set" = "custom" ]; then
			echo "Custom Ambilight mode is set."
			is_set="custom"
		fi

	elif ! [ -z "$ping_avr" ] && ! [ "${hyperion_prio[0]}" = "1" ]; then

		#Set fallback animation
		if ! [ "$power_status" = "Online" ]; then
			power_status="Online"
			echo "AVR is online"
			hyperion-remote -p 11 --effect "Rainbow swirl fast"
		fi

		#Get active AVR input
		avr_input=$(curl -s http://$avr_ip/YamahaExtendedControl/v1/main/getStatus | jq -r '.input' )

		if ! [ "$avr_input" = "$avr_status" ]; then
			avr_status="$avr_input"
			echo "Active input: $avr_input"
		fi

		#HDMI1
		if [ "$avr_input" = "hdmi1" ] && ! [ "$is_set" = "hdmi1" ]; then
			echo "Input is changed to $avr_input: Give priority to Ambilight"
			hyperion-remote -p 2 --clear
			is_set="hdmi1"
		fi

		#HDMI2
		if [ "$avr_input" = "hdmi2" ] && ! [ "$is_set" = "hdmi2" ]; then
			echo "Input is changed to $avr_input: Set color to blue"
			hyperion-remote -p 2 -c blue
			is_set="hdmi2"
		fi

		#Spotify
		if [ "$avr_input" = "spotify" ] && ! [ "$is_set" = "spotify" ]; then
			echo "Input is changed to $avr_input: Set slow rainbow effect"
			hyperion-remote -p 2 --effect "Rainbow swirl"
			is_set="spotify"
		fi

		#Other inputs
		if ! [ "$avr_input" = "hdmi1" ] && ! [ "$avr_input" = "hdmi2" ] && ! [ "$avr_input" = "spotify" ] && ! [ "$is_set" = "undefined" ]; then
			echo "No defined input. Clear priorities."
			hyperion-remote -p 2 -c black
			is_set="undefined"
		fi

	elif ! [ "$power_status" = "Offline" ]; then

		power_status="Offline"
		echo "AVR is offline. Clear all effects."
		hyperion-remote --clearall
		hyperion-remote -c black

	fi

done
