# DanarchyDeploy

dAnarchy Deploy is a template-driven Ruby gem to deploy locally or remotely to Gentoo systems (and debian/ubuntu, more being added). This can take a .JSON or .YAML input file, or a CouchDB connection as a deployment template and install necessary packages, add users and groups, write ERB templates, and decompress tar/zip archives. More documentation incoming.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'danarchy_deploy'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install danarchy_deploy


If you will be running dAnarchy Deploy as a LocalDeploy, it will require root/sudo access, so install the gem with sudo.
   This is RemoteDeploy's process for running LocalDeploy on target hosts (DanarchyDeploy::RemoteDeploy#gem_install [L99-L109]):

   $ sudo gem install danarchy_deploy


## Usage

dAnarchy Deploy usage info can be read with -h/--help:
```ruby
~$ danarchy_deploy -h
Usage: sudo bin/danarchy_deploy (local|remote) --json /path/to/deployment.json [options]
	-j, --json=file                  Read configuration from JSON file.
	-y, --yaml=file                  Read configuration from YAML file.
	-p, --pretend                    Pretend run: Don't take any action.
	-f, --first-run                  First Run: Run as a first run causing services to run all init actions.
	-d, --deploy-dir                 Deployment directory. Defaults to '/danarchy/deploy'.
	--dev-gem    			 Build dAnarchy_deploy gem locally and push to target host in RemoteDeploy.
	--ssh-verbose                	 Verbose SSH stdout/stderr output.
	--vars-verbose                	 Verbose template variable output.
    --skip-install                   Skip package installation and updates.
	--version                    	 Print bin/danarchy_deploy version.
	-h, --help                       Print this help info.
```
