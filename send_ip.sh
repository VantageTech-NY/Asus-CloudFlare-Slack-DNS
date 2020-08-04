#!/bin/bash

# Change me
auth_key="xxxxxxxxxxxxxxxxxxxxxxxx"       # Cloudflare API Key"
zone_identifier="xxxxxxxxxxxxxxxxx"       # Can be found in the "Overview" tab of your cloudflare domain settings
record_name="xxxxxxxxxxxxxxxxxxxxx"       # Record you want to be synced
slackhook="xxxxxxxxxxxxxxxxxxxxxxx"       # The Slack incomming Webhook address

# DO NOT CHANGE LINES BELOW
wan_ip=$(nvram get wan0_ipaddr)

# Script start
echo "[Cloudflare DDNS] Check Initiated"

# Seek for the record
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" \
    -H "Authorization: Bearer $auth_key" \
    -H "Content-Type: application/json")

# Can't do anything without the record
if [[ $record == *"\"count\":0"* ]]; then
  >&2 echo -e "[Cloudflare DDNS] Record does not exist, perhaps create one first?"
  exit 1
fi

# Set existing IP address from the fetched record
old_ip=$(echo "$record" | sed -n 's|.*"content":"\([^"]*\)".*|\1|p')

# Compare if they're the same
if [ $wan_ip = $old_ip ]; then
  echo "[Cloudflare DDNS] IP has not changed, no update required."
  exit 0
fi

# Set the record identifier from result
record_identifier=$(echo "$record" | sed -n 's|.*"id":"\([^"]*\)".*|\1|p')


# The execution of update CloudFlare
update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
    -H "Authorization: Bearer $auth_key" \
    -H "Content-Type: application/json" --data "{\"id\":\"${zone_identifier}\",\"type\":\"A\",\"proxied\":false,\"name\":\"${record_name}\",\"content\":\"${wan_ip}\"}")

# The execution of update Slack
if [ $slackhook ]; then
  echo "[$record_name Cloudflare DDNS] IP has changed, update required."
  curl -X POST -H "Content-type: application/json' --data '{"text":"'"${record_name}: ${wan_ip}"'"}" $slackhook
fi

# The moment of truth
case "$update" in
*"\"success\":false"*)
  >&2 echo -e "[Cloudflare DDNS] Update failed for $record_identifier with IP $wan_ip. DUMPING RESULTS:\n$update"
  exit 1;;
*)
  echo "[$record_name Cloudflare DDNS] IPv4 context '$wan_ip' has been synced to Cloudflare.";;
esac
