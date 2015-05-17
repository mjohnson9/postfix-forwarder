FROM ubuntu
MAINTAINER Michael Johnson <michael@johnson.computer>

COPY debconf.txt /debconf.txt
RUN debconf-set-selections /debconf.txt && rm /debconf.txt

RUN DEBIAN_FRONTEND=noninteractive apt-get update -qq
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -qq -y postfix

COPY confd/confd /opt/confd

COPY confd/virtual_aliases.toml /etc/confd/conf.d/
COPY confd/virtual_aliases.tmpl /etc/confd/templates/

COPY confd/virtual_domains.toml /etc/confd/conf.d/
COPY confd/virtual_domains.tmpl /etc/confd/templates/

COPY start.sh /opt/start.sh

EXPOSE 25
CMD ["/opt/start.sh"]