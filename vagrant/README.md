# In a Virtualbox VM via Vagrant (EXPERIMENTAL)

These are purely experimental instructions for building a Virtualbox VM through Vagrant, and installing
Information Server into it using this Ansible role.

This does not imply this configuration is in any way supported, but could provide a sandbox for some
quick experimentation.

**Important**: as with any use of licensed commercial software

- be very careful not to publish / upload any such vagrant box into a public repository!
- check with your IBM Representative for details on any license entitlement questions or concerns

## Prerequisites

You will need to have pre-installed:

- [Virtualbox](http://virtualbox.org)
- [Vagrant](http://vagrantup.com)
- (And of course this [Ansible role](https://github.com/IBM/ansible-role-infosvr))

## Create a Virtualbox VM

Use the provided `Vagrantfile` in this directory to bring up a headless Virtualbox virtual machine with the
following command:

```bash
$ vagrant up
Bringing machine 'infosvr' up with 'virtualbox' provider...
==> infosvr: Box 'centos/7' could not be found. Attempting to find and install...
    infosvr: Box Provider: virtualbox
    infosvr: Box Version: >= 0
==> infosvr: Loading metadata for box 'centos/7'
    infosvr: URL: https://vagrantcloud.com/centos/7
==> infosvr: Adding box 'centos/7' (v1901.01) for provider: virtualbox
    infosvr: Downloading: https://vagrantcloud.com/centos/boxes/7/versions/1901.01/providers/virtualbox.box
==> infosvr: Box download is resuming from prior download progress
    infosvr: Download redirected to host: cloud.centos.org
==> infosvr: Successfully added box 'centos/7' (v1901.01) for 'virtualbox'!
==> infosvr: Importing base box 'centos/7'...
==> infosvr: Matching MAC address for NAT networking...
==> infosvr: Checking if box 'centos/7' version '1901.01' is up to date...
==> infosvr: Setting the name of the VM: infosvr_infosvr_1550143841541_92812
==> infosvr: Clearing any previously set network interfaces...
==> infosvr: Preparing network interfaces based on configuration...
    infosvr: Adapter 1: nat
    infosvr: Adapter 2: bridged
==> infosvr: Forwarding ports...
    infosvr: 22 (guest) => 2222 (host) (adapter 1)
==> infosvr: Running 'pre-boot' VM customizations...
==> infosvr: Booting VM...
==> infosvr: Waiting for machine to boot. This may take a few minutes...
    infosvr: SSH address: 127.0.0.1:2222
    infosvr: SSH username: vagrant
    infosvr: SSH auth method: private key
    infosvr:
    infosvr: Vagrant insecure key detected. Vagrant will automatically replace
    infosvr: this with a newly generated keypair for better security.
    infosvr:
    infosvr: Inserting generated public key within guest...
    infosvr: Removing insecure key from the guest if it's present...
    infosvr: Key inserted! Disconnecting and reconnecting using new SSH key...
==> infosvr: Machine booted and ready!
==> infosvr: Checking for guest additions in VM...
    infosvr: No guest additions were detected on the base box for this VM! Guest
    infosvr: additions are required for forwarded ports, shared folders, host only
    infosvr: networking, and more. If SSH fails on this machine, please install
    infosvr: the guest additions and repackage the box to continue.
    infosvr:
    infosvr: This is not an error message; everything may continue to work properly,
    infosvr: in which case you may ignore this message.
==> infosvr: Setting hostname...
==> infosvr: Configuring and enabling network interfaces...
```

As you can see from the output above, Vagrant takes care of downloading a base virtual machine (`centos/7`)
and configuring a new Virtualbox virtual machine running it, along with the necessary private keys to login
to the virtual machine.

## Setup default inventory

Define an inventory as follows into a file `hosts.vagrant`:

```ini
[targets]
infosvr.vagrant.ibm.com ansible_user='vagrant' ansible_ssh_private_key_file='<pathToThisDirectory>/.vagrant/machines/infosvr/virtualbox/private_key'

[ibm_information_server_repo]
infosvr.vagrant.ibm.com

[ibm_information_server_domain]
infosvr.vagrant.ibm.com

[ibm_information_server_engine]
infosvr.vagrant.ibm.com

[ibm_information_server_clients]

[ibm_information_server_ug]

[ibm_cognos_report_server]

[ibm_bpm]
```

The configuration above makes use of the fact that the host network in the `Vagrantfile` by default uses a bridged
network, so the virtual machine is given its own IP in the same network the host is running on. If you opt to change
the networking parameters, you may also need to provide a port number as part of the configuration above (eg. `2222`
to connect to the default forwarded port on the localhost).

(Note that we've also added `infosvr.vagrant.ibm.com` to our `/etc/hosts` mapped to the IP address defined in the
`Vagrantfile`, so we can refer to it only by hostname rather than IP.)

## Run the playbook as normal

From here you should be able to run the `IBM.infosvr` role in a playbook as normal, simply using the `hosts.vagrant`
inventory above:

```bash
$ ansible-playbook -i hosts.vagrant <playbook>.yml
```
