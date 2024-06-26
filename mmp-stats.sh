#!/usr/bin/env bash
# This file will contain functions related to gathering stats and displaying it for agent
# Agent will have to call mmp-stats.sh which will contain triggers for configuration files and etc.
# Do not add anything static in this file
GPU_COUNT=$1
LOG_FILE=$2
cd `dirname $0`
. mmp-external.conf
# -- curl API settings --
MINER_API_PORT=5001
stats_json=$(curl --silent --insecure --header 'Accept: application/json' http://127.0.0.1:${MINER_API_PORT}/gpu)
# -- Check if miner is running with API or not --
if [[ $? -ne 0 || -z $stats_json ]]; then
    echo -e "Miner API connection failed"
else

    get_cards_busid(){
        busid=''
        local bus=$(echo $stats_json |jq '.data.gpus[].bus|tonumber')
        if [[ -z "$bus" ]]; then
            local bus="0"
        fi
        if [[ ${bus} > 0 ]]; then
            busid=$(echo $bus)
        fi
    }

    get_miner_shares_ac(){
        local ac=0
        for ((i=0; i < ${GPU_COUNT}; i++ )); do
            local ac=$(echo $stats_json | jq '.data.gpus[]| select('.id' == '$i')|.valid')
            if [[ -z "$ac" ]]; then
                local ac="0"
            fi
            (( total_ac=total_ac+${ac%%.*} ))
        done
        echo "$total_ac"
    }

    get_miner_shares_inv(){
        local inv=0
        for ((i=0; i < ${GPU_COUNT}; i++ )); do
            local inv=$(echo $stats_json | jq '.data.gpus[]| select('.id' == '$i')|.inval')
            if [[ -z "$inv" ]]; then
                local inv="0"
            fi
            (( total_inv=total_inv+${inv%%.*} ))
        done
        echo "$total_inv"
    }

    get_miner_shares_rj(){
        local rj=0
        for ((i=0; i < ${GPU_COUNT}; i++ )); do
            local rj=$(echo $stats_json | jq '.data.gpus[]| select('.id' == '$i')|.statle')
            if [[ -z "$rj" ]]; then
                local rj="0"
            fi
            (( total_rj=total_rj+${rj%%.*} ))
        done
        echo "$total_rj"
    }

    get_miner_stats() {
        stats=
        # Actual data getting
        local index=$(echo $stats_json |jq '.data.gpus[].id|tonumber')
        if [[ "$(( $(echo "${index[*]}" | sort -nr | head -n1) + 1 ))" -ne $GPU_COUNT ]]; then
            GPU_COUNT=$(( $(echo "${index[*]}" | sort -nr | head -n1) + 1 ))
        fi
        local busid=
        get_cards_busid
        local hash=$(echo $stats_json |jq '.data.gpus[].proof|tonumber')
        local units='hs'                    # hashes units
        # A/R shares by pool
        local ac=$(get_miner_shares_ac)
        local inv=$(get_miner_shares_inv)
        local rj=$(get_miner_shares_rj)
        # make JSON
        stats=$(jq -nc \
                --argjson index "$(echo $index| tr " " "\n" | jq -cs '.')" \
                --argjson hash "$(echo $hash | tr " " "\n" | jq -cs '.')" \
                --argjson busid "$(echo ${busid[@]} | tr " " "\n" | jq -cs '.')" \
                --arg units "$units" \
                --arg ac "$ac" --arg inv "$inv" --arg rj "$rj" \
                --arg miner_version "$EXTERNAL_VERSION" \
                --arg miner_name "$EXTERNAL_NAME" \
            '{$index, $busid, $hash, $units, air: [$ac, $inv, $rj], miner_name: $miner_name, miner_version: $miner_version}')
        # total hashrate in khs
        echo $stats
    }
fi
get_miner_stats $GPU_COUNT $LOG_FILE

