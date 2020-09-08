#!/bin/sh
# Update the local copy of the urlhause database of malicious domains

# Keep raw.githubusercontent.com:
#  Even though there is 'some malware' there (according to urlhaus.abuse.ch)
#  there is also a lot of good stuff

if [ $(id -u) -ne 0 ]; then
	echo need to run this as root
	exit 1
fi
# cd /etc/knot-resolver
curl https://urlhaus.abuse.ch/downloads/rpz/ \
	| sed -e 's/\r$//' -e '/raw.githubusercontent.com/d'> /var/lib/knot-resolver/abuse.ch.rpz
