#!/usr/bin/env bash

# Usage: battstat [options] format
# Credit: https://github.com/imwally/battstat
#
# options (give them before the format tokens):
#     -c, --charging-icon       string to display in icon's place when battery is charging
#     -d, --discharging-icon    string to display in icon's place when battery is discharging
#     -t, --threshold <n>       charge (percent) below which the colour turns red (default 10)
#     --hide-above <n>          print nothing unless the charge is below <n> percent
#                               or the battery is fully charged
#     --percent-when-charged    only display percent when charged

# format:
#     {b}    switch to the colour of the charge level
#     {i}    display icon
#     {t}    display time remaining
#     {p}    display percent
# Note: There must be a space between each format token
#
# Prints nothing, and returns 0, on a machine without a battery.

battstat () {

    local battery_details="" charged="" charging="" discharging="" time="" percent=""
    local hours="" minutes="" full_minutes="" icon="" battery_percent=""
    local charging_icon="" discharging_icon="" threshold=10

    # Each get_*_details function returns 1 when there is no battery.

    get_darwin_details () {
        battery_details=$(pmset -g batt 2> /dev/null)

        # No battery (desktop Macs).
        if ! echo "$battery_details" | grep -q InternalBattery; then
            return 1
        fi

        charged=$(echo "$battery_details" | grep -w 'charged')
        charging=$(echo "$battery_details" | grep -w 'AC Power')
        discharging=$(echo "$battery_details" | grep -w 'Battery Power')
        time=$(echo "$battery_details" | grep -Eo '([0-9][0-9]|[0-9]):[0-5][0-9]')
        percent=$(echo "$battery_details" | grep -o "[0-9]*"%)
    }

    get_linux_details () {
        # upower is not installed everywhere (containers, minimal servers)
        battery_details=""
        if command -v upower > /dev/null 2>&1; then
            battery_details=$(upower -e 2> /dev/null | grep 'BAT' | head -n 1)
            if [[ -n "$battery_details" ]]; then
                battery_details=$(LC_ALL=en_US.UTF-8 upower -i "$battery_details" 2> /dev/null)
            fi
        fi

        # No battery, or no upower to ask.
        if [[ -z "$battery_details" ]]; then
            return 1
        fi

        charged=$(echo "$battery_details" | grep 'state' | grep -w 'fully-charged')
        charging=$(echo "$battery_details" | grep 'state' | grep -w 'charging')
        discharging=$(echo "$battery_details" | grep 'state' | grep -w 'discharging')
        percent=$(echo "$battery_details"| grep 'percentage' | awk '{print $2}')

        case $(echo "$battery_details" | grep 'time' | awk '{print $5}') in
        "hours")
            hours=$(echo "$battery_details" | grep 'time' | awk '{print $4}' | cut -d . -f1)
            minutes=$(echo "$battery_details" | grep 'time' | awk '{print $4}' | cut -d . -f2)
            minutes=$(echo .$minutes \* 60 | bc -l | cut -d. -f1)
            ;;
        "minutes")
            minutes=$(echo "$battery_details" | grep 'time' | awk '{print $4}' | cut -d . -f1)
            ;;
        esac

        # Diplay 0 in the hours spot when only minutes remain.
        if [[ -z "$hours" ]]; then
            hours="0"
        fi

        # Prefix 0 when minutes drop below 10.
        if [[ ${#minutes} -eq '1' ]]; then
            minutes="0$minutes"
        fi

        time=$hours:$minutes
    }

    get_openbsd_details () {
        battery_details=$(apm 2> /dev/null)

        # No battery.
        if [[ -z "$battery_details" ]]; then
            return 1
        fi

        charging=$(echo $battery_details | grep -w 'state: connected')
        discharging=$(echo $battery_details | grep -w 'state: not connected')
        percent=$(echo $battery_details | grep -o '[0-9]*%')
        full_minutes=$(echo $battery_details | grep -o ' [0-9]* ')

        # Battery is considered charged when AC is connected and 100%
        if [[ ! -z "$charging" ]] && [[ $percent = "100%" ]]; then
            charged="charged"
        fi

        # Only compute time when available
        if [[ ! -z "$full_minutes" ]]; then
            hours=$(($full_minutes/60))
            minutes=$(($full_minutes%60))

            # Prefix 0 when minutes drop below 10.
            if [[ ${#minutes} -eq '1' ]]; then
            minutes="0$minutes"
            fi

            time=$hours:$minutes
        fi
    }

    hide_percent_until_charged () {
        if [[ -z "$charged" ]]; then
            percent=""
        fi
    }

    print_icon () {
        if [[ ! -z "$charging" ]] || [[ ! -z "$charged" ]]; then
            icon=$charging_icon
        elif [[ ! -z "$discharging" ]]; then
            icon=$discharging_icon
        fi

        [[ $GAUDI_ENABLE_SYMBOLS == true ]] && echo -e -n " $icon "
    }

    print_time () {
        # Display "calc..." when calculating time remaining.
        if [[ -z "$time" ]] || [[ $time = "0:00" ]]; then
          time="calculating..."
        fi

        # Hide time when fully charged.
        if [[ ! -z "$charged" ]]; then
            time=""
        fi

        if [[ ! -z "$time" ]]; then
            printf " %s " $time
        fi

    }

    print_background () {
        # Remove trailing % and symbols for comparison
        battery_percent="$(echo $percent | tr -d '%[,;]')"
        # Change color based on battery percentage
        if [[ $battery_percent == 100 || ! -z "$charged" ]]; then
            echo -e -n "$GAUDI_GREEN"
        elif [[ "$battery_percent" =~ ^[0-9]+$ && $battery_percent -lt $threshold ]]; then
            echo -e -n "$GAUDI_RED"
        else
            echo -e -n "$GAUDI_YELLOW"
        fi
    }

    print_percent () {
        if [[ ! -z "$percent" ]]; then
            printf " %s " $percent
        fi
    }

    case $(uname) in
        "Darwin")
        get_darwin_details || return 0
        ;;
        "Linux")
        get_linux_details || return 0
        ;;
        "OpenBSD")
        get_openbsd_details || return 0
        ;;
        *)
        return 0
        ;;
    esac

    if [[ $# -eq 0 ]]; then
        print_background
        print_time
        print_percent
        print_icon
    fi

    while test $# -gt 0; do
        case "$1" in
        --percent-when-charged)
            hide_percent_until_charged
            shift
            ;;
        -c|--charging-icon)
            charging_icon="$2"
            shift
            shift
            ;;
        -d|--discharging-icon)
            discharging_icon="$2"
            shift
            shift
            ;;
        -t|--threshold)
            threshold="$2"
            shift
            shift
            ;;
        --hide-above)
            battery_percent="$(echo $percent | tr -d '%[,;]')"
            if [[ -z "$charged" && "$battery_percent" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ && $battery_percent -ge $2 ]]; then
                return 0
            fi
            shift
            shift
            ;;
        '{b}')
            print_background
            shift
            ;;
        '{i}')
            print_icon
            shift
            ;;
        '{t}')
            print_time
            shift
            ;;
        '{p}')
            print_percent
            shift
            ;;
        *)
            echo "battstat: unknown argument: $1" >&2
            return 1
            ;;
        esac
    done
}
