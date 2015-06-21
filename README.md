TVPN - the temporary VPN.
=========================
TVPN uses Amazon Web Services to create you a temporary VPN. If you require a
VPN for only a few hours a week, or maybe only when you're travelling this is
probably more cost-effective way to get a VPN connection without paying a
monthly flat fee to a VPN provider. All you require is an Amazon Web Services
account and a credit card to associate to it. If you only use it for an hour,
and transfer a single gigabyte, the cost would be around $0.13 for that
session.

Unlike a lot of cloud-based VPNs like this, this VPN will only cost money when
you are using it. If you never use it again, you will have no AWS bill as all
resources associated with it are cleared from your account.

Here's how you use it:

1. Copy settings.sample.xml to settings.xml
2. Update the configuration variables to specify your AWS API keys
3. Specify what region you want and an AMI within the region (Ubuntu Trusty
   is known to work).
4. Specify what instance type to use. You could use a micro instance on the free
   tier but I have found that they don't provide enough network speed.

Here's how it works:

1. Creates or modifies a security group. The security group is locked down to
   your IP address only so nobody else can connect, even if they somehow knew
   your temporary Elastic IP address.
2. Creates a new keypair that is not related to your normal keypairs. This
   keypair is stored on your system in case you need to log in to the instance.
3. Provisions a new EC2 instance with a script in the user data
4. The script configures a simple VPN server, based on
   [voodoo VPN](https://github.com/sarfata/voodooprivacy)
5. The script installs a small Python server to shut down the instance when it
   is no longer needed.
6. It then configures your machine to connect to the temporary instance on a
   temporary IP address using randomly generated credentials.
7. The script sends a heartbeat to the Python web server every 30 seconds. If it
   doesn't receive the heartbeat for 5 minutes, the instance will automatically
   terminate.

You could run a VPN like this 24/7 if you chose but it probably wouldn't be very
cost-effective compared to a normal VPN provider.
