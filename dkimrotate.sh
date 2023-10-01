#!/bin/bash

# DKIM Rotator in BASH
# Maintainer: Branden Williams, brw@brandolabs.com
# Bash string manip: http://mywiki.wooledge.org/BashFAQ/100#Splitting_a_string_into_fields
#
# General process is this:
# 1) Get a list of domains from the key table file.
# 2) Loop through each entry to accomplish this:
# 	a) Generate new keys for the domain.
#	b) Rename keys with timestamp & domain.
# 3) Update config file to point all domains to new keys
# 4) Update DNS and Restart opendkim

# RULES FOR THIS SCRIPT
#
# 1) All keys will be rotated periodically. The Key identifier needs to be the
#    same for this one. You could add more logic if you like to pick these off
#    one at a time, but right now I'm being a lazy. The logic here prevents
#    key rotation more frequently than monthly. Cron it, yo.
# 2) You must set some default values here, such as the working directory
#    and the config file names. Everyone does things a little differently, so
#    this is my way of trying to make this as universally functional as 
#    possible.
# 3) You must set environment vars for GODADDYKEY and GODADDYSECRET with your
#    Production API keys, and GODADDYOTEKEY and GODADDYOTESECRET with test
#    keys if you wish to use them.

# First, let's define some constants.
WORKINGDIR=/etc/dkimkeys
KEYFILE=key.table
KEYDIR=keys
NEWSERIAL=$(/bin/date "+%Y%m")
EPOCH=$(/bin/date "+%s")
OPENDKIM_GENKEY=/usr/sbin/opendkim-genkey
CURL=/usr/bin/curl
MV=/bin/mv
CHOWN=/bin/chown
SED=/bin/sed
CP=/bin/cp
SLEEP=/bin/sleep
SERVICECMD=/usr/sbin/service

# GoDaddy API setup
TYPE="TXT"
TTL="3600"
PORT="1"
WEIGHT="1"
PRIORITY="0"
PROTOCOL="NONE"
SERVICE="NONE"

# Define an array of domains we want to exclude
exclude_names=("gatherunderpants.com" "questionmark.com" "profit.com")

# For GoDaddy, if you are testing, then use these settings and comment out
# the production ones.
### PROD API ###
#HEADERS="Authorization: sso-key $GODADDYKEY:$GODADDYSECRET"
#APIURL="api.godaddy.com"
### TEST API ###
HEADERS="Authorization: sso-key $GODADDYOTEKEY:$GODADDYOTESECRET"
APIURL="api.ote-godaddy.com"


# Before we do anything, let's back up the only file we're going to change and
# sleep one second in case someone is WICKED FAST.
${CP} "${WORKINGDIR}"/"${KEYFILE}" "${WORKINGDIR}"/"${KEYFILE}".pre-"${NEWSERIAL}"."${EPOCH}"
${SLEEP} 1

# Let's get a list of domains we can loop through.
declare -a domains
readarray -t domains < ${WORKINGDIR}/${KEYFILE}

# Now we're going to loop through each config file line. This will allow us to
# generate new keys for only the domains configured.
i=0
while (( ${#domains[@]} > i )); do
	# First, pull everything to the right of the tabs.
	domain_dkim_config="${domains[i]##*$'\t'}"
	domain_identifier_config="${domains[i]%%$'\t'*}"

	# Second, split into three fields. (1-domain name, 2-serial, 3-keyfile)
	IFS=: read -r -a dkim_config_vars <<< "$domain_dkim_config"

	# Check to see if this domain is in our exclude list
	for excluded_domain in "${exclude_names[@]}"; do
		# Check if the input matches a name
		if [ "${dkim_config_vars[0]}" = "$excluded_domain" ]; then
			((i++))
			continue 2 # continue the while loop
		fi
	done

	# Generate the new keys
	${OPENDKIM_GENKEY} -b 2048 -h sha256 -r -s "${NEWSERIAL}" -d "${dkim_config_vars[0]}" -D ${WORKINGDIR}/${KEYDIR}

	# Rename them accordingly.
	NEWPRIVATEKEY=${WORKINGDIR}/${KEYDIR}/${domain_identifier_config}.${NEWSERIAL}.private
	NEWPUBLICKEY=${WORKINGDIR}/${KEYDIR}/${domain_identifier_config}.${NEWSERIAL}.txt
	${MV} ${WORKINGDIR}/${KEYDIR}/"${NEWSERIAL}".private "${NEWPRIVATEKEY}"
	${MV} ${WORKINGDIR}/${KEYDIR}/"${NEWSERIAL}".txt "${NEWPUBLICKEY}"
	${CHOWN} opendkim:opendkim "${NEWPRIVATEKEY}" "${NEWPUBLICKEY}"

	# Update key.table to have the new config for that particular line item.
	${SED} -i -e "s/${dkim_config_vars[1]}:${dkim_config_vars[2]//\//\\/}/${NEWSERIAL}:${NEWPRIVATEKEY//\//\\/}/" ${WORKINGDIR}/${KEYFILE}

	# Now to send the new records to GoDaddy...
	# This is messy, but so is the file left by OpenDkim. So what I'm doing here
	# is removing whitespace, removing SOME of the quotes (this becomes useful
	# later), putting it all on one line, and then grabbing essentially the
	# actual TXT record ONLY. So yes, messy, but so is their file.
	txtrecord=$(< "${NEWPUBLICKEY}" awk '{$1=$1};1' | ${SED} -e 's/^"//' -e 's/"$//' | tr -d "\n" | cut -d"\"" -f2)

	# Now this bit of kit took a little bit of work. Mostly because this is a new
	# skill for the Doc. Anyway, we now can insert the new record with our domain
	# as we go. So we hit it one by one.
	${CURL} -X PATCH "https://${APIURL}/v1/domains/${dkim_config_vars[0]}/records" \
		-H "Accept: application/json" \
		-H "Content-Type: application/json" \
		-H "${HEADERS}" \
		--data "[ { \"data\": \"${txtrecord}\", \"name\": \"${NEWSERIAL}._domainkey\", \"port\": ${PORT}, \"priority\": ${PRIORITY}, \"protocol\": \"${PROTOCOL}\", \"service\": \"${SERVICE}\", \"ttl\": ${TTL}, \"type\": \"${TYPE}\", \"weight\": ${WEIGHT} } ]"

	((i++))
done

# Restart OpenDkim
# DNS records should be inserted FIRST, then restart opendkim.
${SERVICECMD} opendkim restart
