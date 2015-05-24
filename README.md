# postfix-forwarder
postfix-forwarder is a Docker container that supplies a Postfix forwarding mail server.

## Configuration
**postfix-forwarder is intended to be run on CoreOS.** At minimum, you must be running etcd.

To set etcd's location, specify the `ETCD_HOST` and `ETCD_PORT` environment variables. By default, the container looks at `172.17.42.1:4001` for etcd.

The server's mailname must be specified with the `MAILNAME` environment variable. This should be a fully qualified domain name.

A container may be linked with the alias 'milter' and the Postfix server will send all mail to it in milter format. This allows for, for example, an OpenDKIM server.
Alternatively, the MILTER_PORT environment variable may be set and will be given to the Postfix server. If the variable begins with tcp://, that prefix will be automatically removed.

### etcd keys
postfix-forwarder uses the following etcd keys:
```
/services/ssl/$MAILNAME/cert  - SSL certificate
/services/ssl/$MAILNAME/key   - SSL certificate's private key
/services/ssl/$MAILNAME/ca    - Intermediary CAs (optional)

/services/mail/internal-aliases/*  - Aliases to domainless addresses (it's recommended that you set an alias for the postmaster address at minimum)
/services/mail/aliases/*/*         - Aliases to qualified domains
```

For example, if you wanted to run an MTA with a `MAILNAME` of `mta1.example` and forward mail addressed `example@example` to `example@gmail.com`, your etcd keys would look like the following.
```
/services/ssl/mta1.example/cert =
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----

/services/ssl/mta1.example/key =
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----


/services/mail/internal-aliases/postmaster = example@example
/services/mail/aliases/example/example = example@gmail.com
```

## Copyright and license
postfix-forwarder is licensed under the MIT license, as found in the LICENSE file.
