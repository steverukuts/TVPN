TVPN - the temporary VPN.
=========================
TVPN uses Amazon Web Services to create you a temporary VPN. If you require a
VPN for only a few hours a week, or maybe only when you're travelling this is
probably more cost-effective way to get a VPN connection without paying a
monthly flat fee to a VPN provider. All you require is an Amazon Web Services
account and a credit card to associate to it. If you only use it for an hour,
and transfer a single gigabyte, the cost would be around $0.13 for that
session.

The VPN only sticks around for as long as you require it. It doesn't leave any
resources provisioned when it's complete; when the instance terminates, it
automatically removes its hard disk and IP address, so when you're not using it,
it won't cost you any money.

The application is an unobtrusive system tray application which stores its
configuration in a flat file. You only have to configure your AWS access details
and what region you want your instance to launch in. When you activate the VPN
connection, it will launch a new instance, log in and configure it. A VPN
connection is then automatically established using randomly generated
authentication details.

The application will then continually send a ping message to the instance to
keep it alive. If the instance doesn't receive that message for 5 minutes, it
will automatically terminate.
