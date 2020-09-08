# knot-resolver utilities - call this from .bashrc/.zshrc to add functions
# (requires additional functions in kresd.conf)
# vim:set expandtab:ts=4

# avoid sudo if you're root or in the knot-resolver group
_id=$(id)
if  [[ ! $_id =~ \(root\) ]] && [[ ! $_id =~ \(knot-resolver\) ]]; then
    KNOT_SUDO="sudo"
fi

if [ -d /run/knot-resolver ]; then
    send-knot-resolver () {
        # Send command(s) from stdin to knot-resolver.
        # Cleans up output slightly by removing "> " prompt
        $KNOT_SUDO nc -NU /run/knot-resolver/control/1 \
           | sed 's/^> //'
    }

    # clear dns cache. Prints the previous number of cache entries.
    dns-cache-clear () {
        echo -n "cache.clear()" | send-knot-resolver
    }

    # Retrieve dns-fowarder statistics in json
    dns-stats () {
        echo -n "tojson(stats.list())" | send-knot-resolver
    }

    # reset dns rules back to normal
    dns-reset () {
        echo -n "reset_rules()" | send-knot-resolver
    }

    # bypass dns forwarding rules and forward all queries to the provided IP
    dns-forward-to () {
        local ip="$1"
        # check for empty ip
        # the lua script checks for whether the parameter is valid
        if [ -z "$ip" ]; then
            echo "Missing parameter: ip address"
            return 1
        fi
        echo -n "forward_all_to('$ip')" | send-knot-resolver
    }

    # Blocks abuse by preventing dns lookups for known malicious sites.
    # Param should be 1 or y to enable; 0 or n to disable.
    # This only changes an internal flag, not processing of dns lookups.
    # To active, follow this with a call to either dns-resest or dns-forward-to.
    dns-block-abuse () {
        local truthy=''
        if [ -z "$1" ] || [[ $1 =~ (1|^y|on) ]]; then
            truthy='true'
        else
            truthy='false'
        fi
        echo -n "block_abuse($truthy)" | send-knot-resolver
    }

    # start interactive control session with socket
    knot-ctrl () {
        $KNOT_SUDO nc -U /run/knot-resolver/control/1
    }
fi
