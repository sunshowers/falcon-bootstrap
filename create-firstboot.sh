#!/bin/bash

# Generate a script that makes falcon-VMs accessible in a normal home network

set -o xtrace
set -o pipefail
set -o errexit

TOP=$(cd "$(dirname "$0")" && pwd)

mkdir -p $TOP/cargo-bay
cp ~/.ssh/authorized_keys $TOP/cargo-bay

# Source default configuration
. "$TOP/config/defaults.sh"

# Override defaults by sourcing optional config
if [[ -n $1 ]]; then
    if ! . "$TOP/config/$1.sh"; then
	echo "failed to source configuration"
        exit 1
    fi
fi

#
# Produce the firstboot script that will run in the new guest to set up a basic
# user account.  We try to use the same details as the current user, which
# should ease the use of NFS and SSH if you choose to use them.
#
XID=$(id -u)
XNAME=$(id -un)
XGECOS=$(getent passwd "$XNAME" | cut -d: -f5)
cat >"$TOP/cargo-bay/firstboot.sh" <<EOF
#!/bin/bash
set -o errexit
set -o pipefail
#set -o xtrace
echo 'Just a moment...' >/dev/msglog
/sbin/zfs create 'rpool/home/$XNAME'
/usr/sbin/useradd -u '$XID' -g staff -c '$XGECOS' -d '/home/$XNAME' \\
    -P 'Primary Administrator' -s /bin/bash '$XNAME'
/bin/passwd -N '$XNAME'
/bin/mkdir '/home/$XNAME/.ssh'
/bin/cp /opt/cargo-bay/authorized_keys '/home/$XNAME/.ssh/authorized_keys'
/bin/chown -R '$XNAME:staff' '/home/$XNAME'
/bin/chmod 0700 '/home/$XNAME'
/bin/sed -i \\
    -e '/^PATH=/s#\$#:/opt/ooce/bin:/opt/ooce/sbin#' \\
    /etc/default/login

# Get an IPv4 address via DHCP virtual interface attached to the host interface
ipadm create-addr -T dhcp vioif1/v4

# Create a link-local ipv6 address for the virtual interface used to talk to other falcon VMs
ipadm create-addr -T addrconf vioif0/v6

# Enable DNS lookups
echo 'nameserver $NAMESERVER' > /etc/resolv.conf

# Publish hostname via mdns
# We don't use dhcp because we can't cleanly remove hostnames from arbitrary
# dns servers.
svcadm enable network/dns/multicast

/bin/ntpdig -S 0.pool.ntp.org || true
(
    echo
    echo
    banner 'oh, hello!'
    echo
    echo "You should be able to SSH to your VM:"
    echo
    ipadm show-addr -po type,addr | grep '^dhcp:' |
        sed -e 's/dhcp:/    ssh $XNAME@/' -e 's,/.*,,'
    echo
    echo
) >/dev/msglog

exit 0
EOF

chmod +x "$TOP/cargo-bay/firstboot.sh"