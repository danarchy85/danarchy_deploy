patch_0.2.8
- Switch support from RVM to ASDF

patch_0.2.7
- Patch Templater ERB.new for Ruby versions higher than 2.6
- Allow builtin:: templates in Templater
- System: allow :system:updates in template to control what to install/update
- System: do not return if :system is not defined in template

patch_0.2.6
- DanarchyDeploy: gem install --bindir
- DanarchyDeploy: return from each class if not defined in a deployment
- Services::MySQL: Check for defaults_file instead of /etc/my.cnf, SecureRandom.hex for passwords
- Services::Init: clean up output and if statement
- Add RVM .ruby-version .ruby-gemset
- Rename danarchy_deploy-console to console-dd
- Add CHANGELOG.md

patch_0.2.5
- Adds Fstab system service
- Adds Dmcrypt/LVM system service
- Enforce MongoDB security/limits.d/mongodb.conf if it doesn't exist
- Clarify some CLI output
- Ignore first SSH known_hosts error in RemoteDeploy.remote_mkdir

patch_0.2.4
- mongodb limits newlines

patch_0.2.2
- Fix MongoDB so it correctly applies security limits file count

release_0.2.0
- Adds Applicator #wordpress #nginx #phpfpm #ssl
- Adds Services #init #mongodb #mysql
- Adds System #centos #debian #gentoo #openssue

patch_0.1.6
- User/Groups commands should use sudo

patch_0.1.5
- Don't upload to couchdb if using a .json/.yaml template

patch_0.1.4
- sudoers.d/ file root owned

patch_0.1.3
- prevents packages from being an empty array

patch_0.1.2
- chown/chmod on ~/.ssh contents
- fix JSON parse error

release_0.1.1
- Re-order archive extraction and template creation so that written templates aren't overwritten by archive data.
- Fixes user sudoers.d file creation; a+ append instead of r+ read-write (expects file to exist already).
- Cleans up package handling for Gentoo and also changes --usepkg to --buildpkg if hostname begins with 'image' or 'template' for binary creation during image builds.

