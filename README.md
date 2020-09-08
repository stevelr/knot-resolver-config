# Setup for secure privacy-protecting DNS with DNS-over-TLS

This configuration sets up [knot-resolver](https://www.knot-resolver.cz/), 
a caching DNS resolver, for secure and private DNS handling,
with DNS-over-TLS, automatic blocking of malicious sites,
and dynamic switching of upstream resolvers for VPNs.

I use this on my laptop, but almost no changes would be required to use
this on a server for secure DNS. It replaces more complicated setups
with dnsmasq, stubby, openresolv, etc.

DNS resolution rules:

- DNS resolution is blocked if the URL matches a database of malicious
  domains. The database, [URLhaus from
  abuse.ch](https://urlhaus.abuse.ch/) is updated frequently so you may
  want to automate updating the file. A script is included here to fetch
  it manually.

- The default configuration sends all DNS queries over TLS to 
  [quad9](https://www.quad9.net/) secure servers for privacy protection. 
  The list of upstream servers easy to modify to use servers of your
  choice.

- If a VPN is active, DNS queries are forwarded to the VPN provider's
  DNS server to improves the speed of DNS resolution.
  I'm using a VPN provider
  that is also privacy-proteting (Mullvad VPN), and conveniently uses a
  single ip address for DNS server regardless of your chosen server.

  The switching of DNS servers when going on or off the VPN 
  (between quad9 and vpn) is immediate, because it's checked 
  on every query. 

- There's an option for a local network with a private DNS server,
  such as at home or office. For fully-qualified hosts in that
  domain, requests are forwarded to the local DNS server.

## Included bash/zsh utilities

If you source `knot_resolver.sh` from your .bashrc or .zshrc,
the following commands will be defined:

- __dns-cache-clear__ clear dns cache
- __dns-stats__ print dns statistics in json format
- __dns-forward-to__ temporarily changes forwarding rules so that all
  requests are forwarded to the specified resolver. This is roughly
  equivalent to hand-editing /etc/resolv.conf. To return to the normal
  processing with DNS-over-TLS, use:
- __dns-reset__ reset rules to the 'normal' configuration
- __dns-block-abuse__ enable or disable blocking malicious domains
- __knot-ctrl__ begin an interactive control session with the
  knot-resolver socket. In this session, which also includes a lua
  interpreter, you can call any of the functions in kresd.conf, or
  examine the state of the service.

## Installation

- Install knot-resolver through your system package manager
- After you've customized kresd.conf with your local settings, copy it
  to /etc/knot-resolver.
- Add knot_resolver.sh to your .bashrc/.zshrc
- If you don't have a certificate bundle file already, generate it with 

  ```trust extract --format=pem-bundle tls-ca-bundle.pem```

  and copy the result to /etc/pki/ca-trust/extracted/tls-ca-bundle.pem
- Download the abuse database with
  ```sudo get-bad-domains.sh```
- Start the service `systemctl start kresd@1`. Check that there are no
  errors with `journalctl -xe -u kresd@1`
- You can automatically update the abuse database with systemd timer, as
  described [here](https://blog.frehi.be/2019/02/26/knot-resolver/)

## Captive Portals

With this configuration, I don't have any need for openresolv
(or resolvconf, systemd-resolvconf, etc.), services that
change DNS servers when you switch networks. I want all DNS queries
to use trusted and encrypted servers, all the time.
One situation where that doesn't work is when outgoing DNS requests are
blocked by a captive portal: those login screens you get in a hotel or cafe
that block network traffic until you agree to the 
terms and/or enter a code.
Captive portals are basically a MITM attack: external network activity is
blocked, the only allowed DNS server is theirs, and their DNS server
returns fake responses for all domains to direct you to the login page.

There are a couple ways to address this problem described below

__Approach 1: Captive-browser__

@FiloSottile created a great solution to this problem with 
[captive-browser](https://github.com/FiloSottile/captive-browser), which
does most of the handling automatically, using a dedicated
instance of Chrome browser. The 
captive-browser uses its own internal dns client, pointed to the
captive portal dns server, to load the login screen and let you
navigate through the login procedure.
After you've logged in, you can close the browser. Your system dns
with knot-resolver doesn't need to change at all for this to work.
Of course, you'll want to have installed captive-browser 
(and set up the correct captive-browser.toml file) _before_ you 
need to use it at the hotel/cafe/airplane.

__Approach 2: Command-line__

With a few cli commands, you can switch DNS servers to do the captive
portal login, then switch back.

To do this, you'll need to figure out the DHCP-provided DNS server.
With NetworkManager, you can use this command:

```nmcli -t device show wlan0 | grep IP4.DNS```

(replace wlan0 with the correct interface). An alternate method for
finding the right dns server is a tool called `dhd`,
which does a dhcp request and prints the response. 
Enable the new DNS server with

```dns-forward-to xx.xx.xx.xx``` (DNS IP)

After you have logged in and connect to the internet, restore secure dns
with

```dns-reset```

The `dns-forward-to` and `dns-reset` commands are included in 
`knot_resolver.sh`. Note that there's a small window of time
when _any_ dns request from your system,
including background tasks or other browser tabs, that are unrelated
to logging in to the portal,
will get sent to the portal's unencrypted DNS server,
until you have a chance to preform the `dns-reset`. That window of time
is an opportunity for privacy leakage.
`captive-browser` doesn't have that issue.

