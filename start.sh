#!/bin/sh

if [ -z "$MAILNAME" ]; then
	echo "MAILNAME environment variable is required"
	exit 1
fi

echo $MAILNAME > /etc/mailname

postconf -e "myhostname=$MAILNAME" \
            'myorigin=$mydomain' \
            'mynetworks_style=subnet' \
            'mydestination=' \
            'mailbox_transport=error:this server does not accept mail for local delivery' \
            'smtpd_tls_cert_file=/etc/postfix/cert.pem' \
            'smtpd_tls_key_file=$smtpd_tls_cert_file' \
            'smtpd_tls_security_level=may' \
            'smtp_tls_security_level=may' \
            'smtpd_tls_mandatory_ciphers=high' \
            'smtp_tls_mandatory_ciphers=high' \
            'smtpd_tls_mandatory_protocols=!SSLv2, !SSLv3' \
            'smtp_tls_mandatory_protocols=!SSLv2, !SSLv3' \
            'tls_preempt_cipherlist=yes' \
            'tls_ssl_options=NO_COMPRESSION' \
            'smtpd_tls_dh1024_param_file=/etc/ssl/dh2048.pem' \
            'alias_maps=hash:/etc/postfix/aliases' \
            'alias_database=$alias_maps' \
            'virtual_alias_domains=hash:/etc/postfix/virtual_domains' \
            'virtual_alias_maps=hash:/etc/postfix/virtual_aliases' \
            'smtpd_delay_reject=yes' \
            'smtpd_helo_restrictions = permit_mynetworks, reject_non_fqdn_helo_hostname, reject_invalid_helo_hostname, permit' \
            'smtpd_recipient_restrictions = reject_unauth_pipelining, reject_non_fqdn_recipient, reject_unknown_recipient_domain, permit_mynetworks, reject_unauth_destination, permit' \
            'smtpd_relay_restrictions = permit_mynetworks, defer_unauth_destination' \
            'smtpd_sender_restrictions = permit_mynetworks, reject_non_fqdn_sender, reject_unknown_sender_domain, permit'


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


/opt/confd -watch -node $ETCD &
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
