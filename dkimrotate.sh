#!/bin/bash

# DKIM Rotator in BASH
# Maintainer: Branden Williams, brw@brandolabs.com
# Bash string manip: http://mywiki.wooledge.org/BashFAQ/100#Splitting_a_string_into_fields
#
# General process is this:
# 1) Get a list of domains from the key table file.
# 2) Loop through each entry to accomplish this:
# 	a) Generate new keys for the domain.
#		b) Rename keys with timestamp & domain.
#	3) Update config file to point all domains to new keys
# FUTURE) Update DNS and Restart opendkim

# RULES FOR THIS SCRIPT
#
# 1) All keys will be rotated every month. The Key identifier needs to be the
#    same for this one. You could add more logic if you like to pick these off
#    one at a time, but right now I'm being a lazy.
# 2) You must set some default values here, such as the working directory
#    and the config file names. Everyone does things a little differently, so
#    this is my way of trying to make this as universally functional as possible.

# First, let's define some constants.
WORKINGDIR=/etc/dkimkeys
KEYFILE=key.table
KEYDIR=keys
NEWSERIAL=`/bin/date "+%Y%m"`

# Before we do anything, let's back up the only file we're going to change.
cp ${WORKINGDIR}/${KEYFILE} ${WORKINGDIR}/${KEYFILE}.pre-${NEWSERIAL}

# Let's get a list of domain we can loop through.
declare -a domains
readarray -t domains < ${WORKINGDIR}/${KEYFILE}

# Now we're going to loop through each config file line. This will allow us to
# generate new keys for only the domains configured.
let i=0
while (( ${#domains[@]} > i )); do
	# First, pull everything to the right of the tabs.
	domain_dkim_config="${domains[i]##*$'\t'}"
	domain_identifier_config="${domains[i]%%$'\t'*}"

	# Second, split into three fields using cut. (1-domain name, 2-serial, 3-keyfile)
	IFS=: read -r -a dkim_config_vars <<< "$domain_dkim_config"

	# Generate the new keys
	opendkim-genkey -b 2048 -h sha256 -r -s ${NEWSERIAL} -d ${dkim_config_vars[2]} -D ${WORKINGDIR}/${KEYDIR}

	# Rename them accordingly.
	mv ${WORKINGDIR}/${KEYDIR}/${NEWSERIAL}.private ${WORKINGDIR}/${KEYDIR}/${domain_identifier_config}.${NEWSERIAL}.private
	mv ${WORKINGDIR}/${KEYDIR}/${NEWSERIAL}.txt ${WORKINGDIR}/${KEYDIR}/${domain_identifier_config}.${NEWSERIAL}.txt

	# Update key.table to have the new config for that particular line item.
  sed -i -e "s/${dkim_config_vars[1]}:${dkim_config_vars[2]//\//\\/}/${NEWSERIAL}:${dkim_config_vars[2]//\//\\/}/" ${WORKINGDIR}/${KEYFILE}

	# Future expansion, automatically update your DNS provider with the new record here.

	((i++))
done

# Restart OpenDkim
# This is commented out for now because the DNS records are not automatically put
# into service. DNS records should be inserted FIRST, then restart opendkim.
#service opendkim restart
