#!/bin/sh

if [ -z "$MAILNAME" ]; then
	echo "MAILNAME environment variable is required"
	exit 1
fi

echo $MAILNAME > /etc/mailname

postconf -e 'myorigin=$mydomain' \
            'mynetworks_style=subnet' \
            'mydestination=' \
            'mailbox_transport=error:this server does not accept mail for local delivery' \
            'smtpd_tls_cert_file=/etc/postfix/cert.pem' \
            'virtual_alias_domains=hash:/etc/postfix/virtual_domains' \
            'virtual_alias_maps=hash:/etc/postfix/virtual_aliases'

# Utilize the init script to configure the chroot (if needed)
/etc/init.d/postfix start > /dev/null
/etc/init.d/postfix stop > /dev/null

# The init script doesn't always stop
# Ask postfix to stop itself as well, in case there's an issue
postfix stop > /dev/null 2>/dev/null

export ETCD_PORT=${ETCD_PORT:-4001}
export HOST_IP=${HOST_IP:-172.17.42.1}
export ETCD=$HOST_IP:$ETCD_PORT

echo "waiting for confd to create primary configuration files"
until /opt/confd -onetime -node $ETCD; do
    sleep 1s
done


/opt/confd -watch -node $ETCD -config-file $tomlFile &
echo "confd is now monitoring for changes in primary configuration files..."

echo "waiting for confd to create initial SSL certificate"
until /opt/confd -onetime -node $ETCD -prefix "/services/ssl/$MAILNAME" -confdir /opt/confd-ssl; do
    sleep 1s
done

/opt/confd -watch -node $ETCD -prefix "/services/ssl/$MAILNAME" -confdir /opt/confd-ssl &
echo "confd is now monitoring SSL certificate for changes..."

postmap /etc/postfix/virtual_aliases
postmap /etc/postfix/virtual_domains

trap_hup_signal() {
    echo "Reloading (from SIGHUP)"
    postfix reload
}

trap_term_signal() {
    echo "Stopping (from SIGTERM)"
    postfix stop
    exit 0
}

# Postfix conveniently, doesn't handle TERM (sent by docker stop)
# Trap that signal and stop postfix if we recieve it
trap "trap_hup_signal" HUP
trap "trap_term_signal" TERM

/usr/lib/postfix/master -c /etc/postfix -d &
pid=$!

# Loop "wait" until the postfix master exits
while true; do
	wait $pid
	exitcode=$?
	test $? -gt 128 || break;
    kill -0 $pid 2> /dev/null || break;
done

exit $exitcode
