# xsrv.graylog

This role will install and configure [Graylog](https://github.com/Graylog2/graylog2-server), an open source log management, capture and analysis platform.

_Note: the [SSPL license](https://www.graylog.org/post/graylog-v4-0-licensing-sspl) used by Graylog and MongoDB is [not recognized as an Open-Source license](https://opensource.org/node/1099) by the Open-Source Initiative. Make sure you understand the license before offering a publicly available Graylog-as-a-service instance._

[![](https://i.imgur.com/tC4G9mQm.png)](https://i.imgur.com/tC4G9mQ.png)
[![](https://i.imgur.com/eGCL45L.jpg)](https://i.imgur.com/6Zu7YKy.png)


## Requirements/dependencies/example playbook

- See [meta/main.yml](meta/main.yml)
- Graylog/ElasticSearch requires at least 4GB of RAM to run with acceptable performance in a basic setup [[1](https://community.graylog.org/t/graylog2-system-requirement/2752/2)]. Fast disks are recommended.

```yaml
# playbook.yml
- hosts: my.CHANGEME.org
  roles:
     - nodiscc.xsrv.common # optional
     - nodiscc.xsrv.monitoring # optional
     - nodiscc.xsrv.apache # reverse proxy and SSL/TLS certificates
     - nodiscc.xsrv.graylog

# required variables:
# host_vars/my.CHANGEME.org/my.CHANGEME.org.yml
graylog_fqdn: "logs.CHANGEME.org"
# ansible-vault edit host_vars/my.CHANGEME.org/my.CHANGEME.org.vault.yml
graylog_root_username: "CHANGEME"
graylog_root_password: "CHANGEME20"
graylog_secret_key: "CHANGEME96"
```

See [defaults/main.yml](defaults/main.yml) for all configuration variables


- Firewall/NAT must allow incoming connections to all ports configured as [inputs](#usage) (eg. `tcp/5140`)

```yaml
firehol_networks:
  - name: ...
    allow_input: # incoming traffic
      - { name: "graylogtcp5140", src: "{{ my_trusted_syslog_ip_addresses }}" } # graylog syslog input (TCP/SSL) from trusted addresses
```

- Remote hosts must be configured to send their logs to the graylog instance. For example with the [monitoring](../monitoring) role:

```yaml
### LOGGING (RSYSLOG) ###
rsyslog_enable_forwarding: yes
rsyslog_forward_to_hostname: "my.CHANGEME.org"
rsyslog_forward_to_port: 5140
```


## Usage

### Basic setup

Login to your graylog instance and configure a basic **[input](https://docs.graylog.org/en/latest/pages/sending_data.html)** to accept syslog messages on TCP port 5140 (using TLS):

- Title: `Syslog/TLS/TCP`
- Port: `5140`
- TLS cert file: `/etc/graylog/ssl/graylog-ca.crt` (the default, self-signed cert)
- TLS private key: `/etc/graylog/ssl/graylog-ca.key` (the default, self-signed cert)
- TLS client authentication: `disabled` (not implemented yet)
- TLS client auth trusted certs: `/etc/graylog/ssl/graylog-ca.crt`
- [x] Allow overriding date?
- Save

Add **[Extractors](https://docs.graylog.org/en/4.0/pages/extractors.html)** to the input to build meaningful data fields (addresses, processes, status...) from incoming, unstructured log messages (using regex or _Grok patterns_). Example grok pattern for [firehol](../common/) messages:

- Source field: `message`
- [x] Named captures only
- Pattern: `\[ *%{NUMBER}\] \[firehol\]%{WORD:action} %{WORD:rule} (?<chain>.....)IN=%{WORD:in-interface}? OUT=%{WORD:out_interface}? (MAC=(?<mac_address>[a-f0-9:]*) )?SRC=%{IPV4:source_ip} DST=%{IPV4:destination_ip} LEN=%{NUMBER:length} TOS=0x%{NUMBER} PREC=0x%{NUMBER} TTL=%{NUMBER:ttl} ID=%{NUMBER:id} %{WORD} PROTO=%{WORD:protocol} SPT=%{NUMBER:source_port} DPT=%{NUMBER:destination_port} (WINDOW=%{NUMBER:window} RES=0x%{NUMBER} %{DATA:flags} )?(LEN=%{NUMBER} )?(URGP=%{NUMBER})?`
- Condition: `Only attempt extraction if field contains string`
- Field contains string: `[firehol]`
- Extractor title: `firehol message extractor`

Create **[streams](https://docs.graylog.org/en/latest/pages/streams.html)** to route messages into categories in realtime while they are processed, based on conditions (message contents, source input...). Select wether to cut or copy messages from the `All messages` default stream. Queries in a smaller, pre-filtered stream will run faster than queries in a large unfiltered `All messages` stream.  For example, setup a basic filter to copy all firehol messages to a separate stream:

- Create stream
  - Title: `firewall messages`
  - Description: `firewall messages`
  - [ ] Remove matches from 'All messages' stream
- More Actions > Quick Add Rule
  - Field: `message`
  - Type: `contain`
  - Value: `firehol`
- Start Stream

Start using Graylog to [search and filter](https://docs.graylog.org/en/4.0/pages/searching/query_language.html) through messages, edit table fields, create aggregations (bar/area/line/pie charts, tables...) and progressively build useful **[dashboards](https://docs.graylog.org/en/latest/pages/dashboards.html)** showing important indicators for your specific setup.

![](https://i.imgur.com/0OCFJlx.png)

Setup [authentication](https://docs.graylog.org/en/latest/pages/permission_management.htmln#authentication) and [roles](https://docs.graylog.org/en/latest/pages/permission_management.html#roles) settings allow granting read or write access to specific users/groups. LDAP is supported.


## Backups

TODO

<!--
See the included [rsnapshot configuration](templates/etc_rsnapshot.d_graylog.conf.j2)
There are no backups of log data. Use `bsondump` from the `mongo-tools` package to manipulate mongodb backups.
-->

## References

- https://stdout.root.sx/links/?searchterms=graylog