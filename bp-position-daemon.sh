#!/bin/bash
################################################################################
#
# VEX BP Position Monitor
# Daemon that sends pm in telegram using bot functionality on changing position
#
# Git Hub: https://github.com/genesisblockid/bp-alert-bot
# VEX Network Monitor: https://explorer.vexanium.com/
#
###############################################################################


#-- Config ------------------------------
LAST_POSITION=22;

# for what name moniotr position
PRODUCER_NAME_CHECK="namebp"


# Register your Telegram Bot here @BotFather and get your Bot Token like 46354643:JHASDGFJSDJS-dsfdjhf
TELEGRAM_BOT_ID="token bot"

# Users telegram IDS. All who open joined your bot will leave his IDs here  "https://api.telegram.org/bot"+BOT_ID+"/getUpdates"
TELEGRAM_CHAT_IDS=("-40609" "-10015051" "11215")

# time between check system contract in seconds
TIME_BETWEEN_CHECKS=5

# Name of log file
LOG_FILE="log_PlaceMonitor.log"

# # Path to you cleos wrapper
# CLEOS=/path/to/cleos/cleos.sh

# Min Votes change to inform
MIN_VEX_VOTES_INFORM=100

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
TELEGRAM_API="https://api.telegram.org/bot"
TELEGRAM_SEND_MSG="$TELEGRAM_API$TELEGRAM_BOT_ID/sendMessage"

sendmessage(){
    for i in "${TELEGRAM_CHAT_IDS[@]}"
    do
	curl $TELEGRAM_SEND_MSG -X POST -d 'chat_id='$i'&text='"$1" >/dev/null 2>/dev/null
    done
}


getVoteWeight(){
    timestamp_epoch=946684800
    now="$(date +%s)"
    let "dates_=$now-$timestamp_epoch"
    let "weight_=$dates_/(86400*7)"
    weight=$(bc <<< "scale=16;$weight_/52")
    res=$(bc -l <<< "e($weight*l(2))")
    echo $res
}
#=====================================================================
#=====================================================================
LAST_VEX_VOTES=0;

while true; do

    DATE=`date`
	POSITION=0;

	PROD_LIST=$(clivex --url https://explorer.vexanium.com:6960 system listproducers -l 150 -j)

	VOTE_WEIGHT=$(getVoteWeight)
	TOTAL_VOTE_WEIGHT=$(echo $PROD_LIST | jq -r '.total_producer_vote_weight' | cut -f1 -d".")

	for row in $(echo "${PROD_LIST}" | jq -r '.rows[] | @base64'); do
		_jq() {
			echo ${row} | base64 --decode | jq -r ${1}
		}

		NAME=$(_jq '.owner')
		TOTAL_VOTES=$(_jq '.total_votes' | cut -f1 -d".")
		PROC=$(bc <<< "scale=3; $TOTAL_VOTES*100/$TOTAL_VOTE_WEIGHT")

		VEX_VOTES=$(bc <<< "scale=4; $TOTAL_VOTES/$VOTE_WEIGHT/10000")
		VEX_VOTES_NICE=$(echo $VEX_VOTES | sed ':a;s/\B[0-9]\{3\}\>/ &/;ta')

        POSITION=$(($POSITION+1))

        MSG2="";
        if [[ "$NAME" == "$PRODUCER_NAME_CHECK" ]]; then
			if [[ $POSITION != $LAST_POSITION && $LAST_POSITION != -1 ]]; then

				SYMBOL="▲"
				if [[ $POSITION > $LAST_POSITION ]]; then
					SYMBOL="▼"
				fi
				MSG="🔔 Producer Notif %0A%0A 📅 Date: $DATE %0A%0A$SYMBOL: Producer bpname Position Changed  $LAST_POSITION -> $POSITION - $PROC% %0A%0A TOTAL VOTE: $VEX_VOTES_NICE VEX %0A%0A You can vote https://vexascan.com/producer/bpname "


				# in case you move to top 21 from standby
				if [[ $LAST_POSITION -gt 21 && $POSITION -le 21 ]]; then
					MSG2="✈ Be ready you are in top 21! You will start producing soon (in 2-3 rounds)"
				fi

				# in case you move out from top 21 to standby
				if [[ $LAST_POSITION -le 22 && $POSITION -gt 22 ]]; then
				    MSG2="💤 your node moved to stadnby"
				fi

				echo $MSG >> $LOG_FILE

				sendmessage "$MSG"
				if [[ "$MSG2" != "" ]]; then
					echo $MSG2 >> $LOG_FILE
					sleep 1
					sendmessage "$MSG2"
				fi

				#echo "--" >> $LOG_FILE
				LAST_POSITION=$POSITION
				break
			fi

			if [[ $LAST_VEX_VOTES == 0 ]]; then
				LAST_VEX_VOTES=$VEX_VOTES;
			fi

			if [[ $LAST_VEX_VOTES != $VEX_VOTES && $LAST_VEX_VOTES > 0 ]]; then
				DIFF=$(bc <<< "$VEX_VOTES - $LAST_VEX_VOTES");
                if (( $(echo "$DIFF > 0" |bc -l) )); then
					SYM="✚"
                else
					SYM="▬ "
					DIFF=$(bc <<< "scale=2;-1*$DIFF")
                fi

				if (( $(echo "$DIFF > $MIN_VEX_VOTES_INFORM" |bc -l) )); then
                	DIFF_NICE=$(echo $DIFF | sed ':a;s/\B[0-9]\{3\}\>/ &/;ta')

                	MSG="$SYM$DIFF_NICE VEX Votes --> $VEX_VOTES_NICE VEX [$PROC%]";
                	sendmessage "$MSG"
				fi
				
				LAST_VEX_VOTES=$VEX_VOTES
			fi
		fi
	done

    sleep $TIME_BETWEEN_CHECKS;
done




