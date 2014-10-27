#!/bin/bash

source ./install_env.bash

# statsd
git -C /opt clone https://github.com/rackerlabs/blueflood-statsd-backend.git
cd /opt/blueflood-statsd-backend
npm install

git -C /opt clone https://github.com/etsy/statsd.git
cd /opt/statsd
npm install
cat > /etc/statsd_config.js << EOL
{
  port: 8125,
  debug: true,
  address: '127.0.0.1',
  flushInterval: 30000,
  prefixStats: "dev.${HOSTNAME}",
  backends: [
    './backends/console',
    '../blueflood-statsd-backend'
  ],
  console: {
    prettyprint: true
  },
  blueflood: {
    tenantId: "${TENANT_ID}",
    endpoint: 'http://iad.metrics-ingest.api.rackspacecloud.com:80',
    authModule: './auth',
    authClass: 'RaxAuth',
    authParams: {
      raxusername: "${USERNAME}",
      raxapikey: "${APIKEY}"
    }
  },
  log: {
    level: 'LOG_DEBUG'
  }
}
EOL

cat > /etc/init/statsd.conf << EOL
description "statsd server"
start on runlevel [2345]
stop on runlevel [!2345]
console log
respawn
respawn limit 10 5
chdir /opt/statsd
exec nodejs stats.js /etc/statsd_config.js
EOL
start statsd

cat > /root/push_statsd.bash << EOL
#!/bin/bash
echo "dev.statsd.${HOSTNAME}.random_gauge:\$RANDOM|g" | nc -u -w0 127.0.0.1 8125
echo "dev.statsd.${HOSTNAME}.constant_counter:1|c" | nc -u -w0 127.0.0.1 8125
EOL
chmod +x /root/push_statsd.bash

cat > /etc/cron.d/push_to_statsd << EOL
* * * * * /root/push_statsd.bash
* * * * * sleep 10; /root/push_statsd.bash
* * * * * sleep 20; /root/push_statsd.bash
* * * * * sleep 30; /root/push_statsd.bash
* * * * * sleep 40; /root/push_statsd.bash
* * * * * sleep 50; /root/push_statsd.bash
EOL
chmod 755 /etc/cron.d/push_to_statsd
crontab /etc/cron.d/push_to_statsd
