Description
===========

This template deploys a [Grafana](http://grafana.org) server pointed to [Rackspace](http://rackspace.com) Cloud Metrics as a backend.

Requirements
============
* An OpenStack username, password, and tenant id.
* [python-heatclient](https://github.com/openstack/python-heatclient)
`>= v0.2.8`:

```bash
pip install python-heatclient
```

We recommend installing the client within a [Python virtual
environment](http://www.virtualenv.org/).

Example Usage
=============
Here is an example of how to deploy this template using the
[python-heatclient](https://github.com/openstack/python-heatclient):

```
heat \
  --os-username <OS-USERNAME> \
  --os-password <OS-PASSWORD> \
  --os-tenant-id <TENANT-ID> \
  --os-auth-url https://identity.api.rackspacecloud.com/v2.0/ \
  stack-create mygrafanadashboard -f grafana.yaml \
  -P rax_tenant=$RAX_TENANT_ID \
  -P rax_username=$RAX_USER_NAME \
  -P rax_apikey=$RAX_API_KEY \
  -P host_name=$WHATEVER_URL_YOU_WANT
```

* For UK customers, use `https://lon.identity.api.rackspacecloud.com/v2.0/` as
the `--os-auth-url`.

Optionally, set environment variables to avoid needing to provide these
values every time a call is made:

```
export OS_USERNAME=<USERNAME>
export OS_PASSWORD=<PASSWORD>
export OS_TENANT_ID=<TENANT-ID>
export OS_AUTH_URL=<AUTH-URL>
```

Parameters
==========
Parameters can be replaced with your own values when standing up a stack. Use
the `-P` flag to specify a custom parameter.

* `rax_tenant`: The Rackspace tenant ID the grafana server will use.  This is the numeric id for the user, not the username.
* `rax_username`: The Rackspace username the grafana server will use.
* `rax_apikey`: The API key for the Rackspace user the grafana server will use.  You can find this by logging in to mycloud.rackspace.com and navigating to the 'Accounts Settings' page ([https://mycloud.rackspace.com/cloud/<rax_tenant>/account#settings](https://mycloud.rackspace.com/cloud/<rax_tenant>/account#settings))
* `host_name`: (optional) Domain to be used for the grafana sever. Note that you must set up this domain separately: the template does not register the domain for you.
* `apache_auth_user`: (optional) User name used to authenticate into Apache.  Default username: 'grafana'.
* `flavor` . Cloud Server flavor (size) to use. Default flavor: '2GB Standard Instance'.
* `es_version`. Elastsearch version to use.  Default Elasticsearch version: '1.3.4'.
* `gr_version`. Grafana version to use. Default Grafana version: '1.8.1'.

Outputs
=======
Once a stack comes online, use `heat output-list` to see all available outputs.
Use `heat output-show <OUTPUT NAME>` to get the value fo a specific output.

* `private_key`: SSH private that can be used to login as root to the servers.
* `public_ip`: IP of the server created with this deployment.
* `apache_auth_user`: basic http auth username (default: 'grafana').
* `apache_auth_password`: basic http auth password.


For multi-line values, the response will come in an escaped form. To get rid of
the escapes, use `echo -e '<STRING>' > file.txt`. For vim users, a substitution
can be done within a file using `%s/\\n/\r/g`.

Stack Details
=============
The application is deployed [Capistrano](http://capistranorb.com/)-style
in the home directory of the `rails` user in a directory based on the name of
the git repo.

Gems dependencies are installed by running a `bundle install --deployment` in
the application directory. This requires a Gemfile.lock in the application
repo.

Two rake tasks are run at deployment time: `rake db:migrate` followed by
`rake assets:precompile`. Additional rake tasks will be run if provided.

If you are using unicorn it must be declared in the application's Gemfile.

A unicorn.rb file is generated and placed in the application's config
directory along with a database.yml file configured to reference the
deployment's database server.

Contributing
============
For contributions to the Rackspace Cloud Metrics backend store that powers this dashboard, please refer to the [Blueflood](https://github.com/rackerlabs/blueflood) project.  More information at [http://blueflood.io](http://blueflood.io) and on IRC on Freenode on the #blueflood channel.

For contributions to this template, pull requests are always welcome and will be reviewed as quickly as possible.

For all Heat-related contributions, please note thtat there are substantial changes still happening within the [OpenStack
Heat](https://wiki.openstack.org/wiki/Heat) project. Template contribution guidelines will be drafted in the near future.

License
=======
```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
