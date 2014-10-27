#!/bin/bash

source ./install_env.bash

APACHE_AUTH_USER=grafana
APACHE_AUTH_PASSWORD=gggrrraaafffaaannnaaa

export DEBIAN_FRONTEND=noninteractive

# this is so that oracle java can be installed without user intervention.
echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections

# get ready for java.
add-apt-repository -y ppa:webupd8team/java
apt-get update -y --force-yes

# install all the packages.
echo installing packages now, one at a time.
for i in wget oracle-java7-installer vim git nginx nginx-extras apache2-utils python-dev python-setuptools python-pip build-essential libcairo2-dev libffi-dev python-virtualenv python-dateutil python-software-properties nodejs npm; do
  echo installing "$i"
  apt-get install -y $i --force-yes 2>&1 | tee /tmp/$i.install.log
done

# install elasticsearch
curl -o /tmp/elasticsearch-${ES_VERSION}.deb https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${ES_VERSION}.deb
dpkg -i /tmp/elasticsearch-${ES_VERSION}.deb
update-rc.d elasticsearch defaults 95 10

# configure elasticsearch
mv /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch-default.yml
echo cluster.name: es_grafana > /etc/elasticsearch/elasticsearch.yml
echo network.host: 127.0.0.1 >> /etc/elasticsearch/elasticsearch.yml
/etc/init.d/elasticsearch start

# set up auth for nginx
htpasswd -b -c /etc/nginx/.htpasswd ${APACHE_AUTH_USER} ${APACHE_AUTH_PASSWORD}

# install grafana
curl -o /tmp/grafana-${GR_VERSION}.tar.gz http://grafanarel.s3.amazonaws.com/grafana-${GR_VERSION}.tar.gz
tar -xzf /tmp/grafana-${GR_VERSION}.tar.gz -C /usr/share/nginx/
ln -s /usr/share/nginx/grafana-${GR_VERSION} /usr/share/nginx/grafana
chown -R root:root /usr/share/nginx/grafana-${GR_VERSION}

# configure nginx to reverse proxy graphite-web and elasticsearch, and still serve grafana.
rm /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/grafana << EOL
upstream graphite {
  server 127.0.0.1:8888;
}
upstream elasticsearch {
  server 127.0.0.1:9200;
}
server {
  listen 80;
  auth_basic 'Restricted';
  auth_basic_user_file /etc/nginx/.htpasswd;
  location /graphite/ {
    rewrite /graphite/(.*) /\$1 break;
    proxy_pass http://graphite;
    proxy_redirect off;
    proxy_set_header Host \$host;
  }
  location /elasticsearch/ {
    rewrite /elasticsearch/(.*) /\$1 break;
    proxy_pass http://elasticsearch;
    proxy_redirect off;
    proxy_set_header Host \$host;
  }
  location / {
    root /usr/share/nginx/grafana;
  }
}
EOL
ln -s /etc/nginx/sites-available/grafana /etc/nginx/sites-enabled/grafana
/etc/init.d/nginx restart

# install graphite-api
pip install graphite-api gunicorn
git -C /tmp clone https://github.com/gdusbabek/blueflood.git

# install the Cloud Metrics graphite finder
git -C /tmp/blueflood checkout graphite_compat
cd /tmp/blueflood/contrib/graphite
python setup.py install

# configure graphite-api
cat > /etc/graphite-api.yaml << EOL
search_index: /dev/null
finders:
  - blueflood.TenantBluefloodFinder
functions:
  - graphite_api.functions.SeriesFunctions
  - graphite_api.functions.PieFunctions
time_zone: UTC
blueflood:
  tenant: ${TENANT_ID}
  username: ${USERNAME}
  apikey: ${APIKEY}
  urls:
    - http://iad.metrics.api.rackspacecloud.com
EOL

# configure grafana
cat > /usr/share/nginx/grafana/config.js << EOL
define(['settings'],
function (Settings) {
  return new Settings({
    datasources: {
      graphite: {
        type: 'graphite',
        url: 'http://'+window.location.hostname+'/graphite',
      },
      elasticsearch: {
        type: 'elasticsearch',
        url: 'http://'+window.location.hostname+'/elasticsearch',
        index: 'grafana-dash',
        grafanaDB: true,
      }
    },
    search: {
      max_results: 20
    },
    default_route: '/dashboard/file/default.json',
    unsaved_changes_warning: true,
    playlist_timespan: '1m',
    admin: {
      password: ''
    },
    plugins: {
      panels: []
    }
  });
});
EOL

echo ${TENANT_ID} > ~/tenant_id

# configure graphite-api
cat > /etc/init/graphite-api.conf << EOL
description "Graphite-API server"
start on runlevel [2345]
stop on runlevel [!2345]
console log
respawn
exec gunicorn -b 127.0.0.1:8888 -w 4 graphite_api.app:app
EOL
start graphite-api

# get ready for raxmon
cat > /root/.raxrc << EOL
[credentials]
username=${USERNAME}
api_key=${APIKEY}
[api]
url=https://monitoring.api.rackspacecloud.com/v1.0
EOL

# set up cloud monitoring.
wget http://meta.packages.cloudmonitoring.rackspace.com/ubuntu-14.04-x86_64/rackspace-cloud-monitoring-meta-stable_1.0_all.deb
dpkg -i rackspace-cloud-monitoring-meta-stable_1.0_all.deb
apt-get update
apt-get install rackspace-monitoring-agent
pip install rackspace-monitoring-cli
service rackspace-monitoring-agent stop
rm /var/lib/cloud/data/instance-id
rackspace-monitoring-agent --setup --username ${USERNAME} --apikey ${APIKEY} --production
service rackspace-monitoring-agent start

# capture our entity id and configure some checks.
# work around a bug where the entity users "cloud_server" but the hostname contains "cloud-server"
raxmon-entities-list > /tmp/all_entities.txt
sed -i -e "s/cloud_server/cloud-server/g" /tmp/all_entities.txt
cat /tmp/all_entities.txt | grep `cat /var/lib/cloud/data/previous-hostname` | grep -oEi '(en[0-9a-zA-Z]{8,8})' > /root/entity_id
raxmon-checks-create --type agent.cpu --label cpu --entity-id `cat /root/entity_id` --details="grafana" --target-alias `ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'` | grep -oEi '(ch[0-9a-zA-Z]{8,8})' > /root/cpu_check_id
raxmon-checks-create --type agent.memory --label memory --entity-id `cat /root/entity_id` --details="grafana" --target-alias `ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'` | grep -oEi '(ch[0-9a-zA-Z]{8,8})' > /root/memory_check_id
raxmon-checks-create --type agent.disk --label disk --entity-id `cat /root/entity_id` --details="target=/dev/xda1" | grep -oEi '(ch[0-9a-zA-Z]{8,8})' > /root/disk_check_id
raxmon-checks-create --type agent.network --label network --entity-id `cat /root/entity_id` --details="target=eth0" | grep -oEi '(ch[0-9a-zA-Z]{8,8})' > /root/network_check_id

# now create a dashboard.
curl https://gist.githubusercontent.com/gdusbabek/c3feab2849f9583797b4/raw/cf46c35a9cef5190edef0c54c8a1e9b7808172a3/cloud_metrics_default_dashboard.json > /tmp/dashboard.json
sed -i -e "s/_rax_entity_id_/`cat /root/entity_id`/g" /tmp/dashboard.json
mv /usr/share/nginx/grafana/app/dashboards/default.json /usr/share/nginx/grafana/app/dashboards/old_default.json
cp /tmp/dashboard.json /usr/share/nginx/grafana/app/dashboards/default.json
