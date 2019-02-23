# In a Docker container (EXPERIMENTAL)

These are purely experimental instructions for building a Docker container using this Ansible role.

This is neither in any way supported, nor in any way following best practices for this kind of approach;
however, if you're after a consistent rollback point for some quick experimentation (without needing to
keep a large VM around), this could be useful.

**Important**: as with any use of licensed commercial software

- be very careful not to push any such container into a public repository!
- check with your IBM Representative for details on any license entitlement questions or concerns

**NOTICE**: THESE INSTRUCTIONS ARE OUT OF DATE, IN THE PROCESS OF BEING UPDATED TO DESCRIBE BUILDING A
CONTAINER WITHOUT REQUIRING `--privileged` OR SSH.

## Prerequisites

You will need to have pre-installed:

- [Docker](http://docker.com)
- (And of course this [Ansible role](https://github.com/IBM/ansible-role-infosvr))

## TL;DR

The more detailed explanation below walks through what these playbooks are actually doing, but if you simply want
to get up and running as quickly as possible you can use the following quick steps. (Note that if you want to 
customise anything, you should really read the more detailed explanation below to determine where you may want 
to make modifications!)

### Prepare an SSH key pair

Create a new SSH key pair to use for your container(s):

```bash
$ ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/home/<you>/.ssh/id_rsa): 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/<you>/.ssh/id_rsa.
Your public key has been saved in /home/<you>/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:Up6KjbnEV4Hgfo75YM393QdQsK3Z0aTNBz0DoirrW+c <you>@<host>
The key's randomart image is:
+---[RSA 2048]----+
|    .      ..oo..|
|   . . .  . .o.X.|
|    . . o.  ..+ B|
|   .   o.o  .+ ..|
|    ..o.S   o..  |
|   . %o=      .  |
|    @.B...     . |
|   o.=. o. . .  .|
|    .oo  E. . .. |
+----[SHA256]-----+
```

Copy the generated public key (`~/.ssh/id_rsa.pub` if you used the defaults above) into the same directory as
the playbooks used below (eg. this directory).

### Setup default inventory

Define an inventory as follows into a file `hosts.container`:

```ini
[targets]
infosvr.container.ibm.com ansible_user='root' ansible_ssh_private_key_file='~/.ssh/id_rsa' ansible_port=22222 ansible_host=localhost

[ibm-information-server-repo]
infosvr.container.ibm.com

[ibm-information-server-domain]
infosvr.container.ibm.com

[ibm-information-server-engine]
infosvr.container.ibm.com

[ibm-information-server-clients]

[ibm-information-server-ug]

[ibm-cognos-report-server]

[ibm-bpm]
```

### Build a new image

Run the `build.yml` playbook provided in this directory as follows (providing the version number you're deploying to `tag_name=`):

```bash
$ ansible-playbook -i hosts.container build.yml -e tag_name=v11.X.X.X
```

This will automatically:

- Create the `infosvr_base` image for you (or re-use it if it has already been created), including your key pair as an
    authorized_key to SSH into the container
- Run a new container using the `infosvr_base` image, with the necessary settings for an install of Information Server
- Fake the container as a normal Linux system, by overriding `/proc/version`
- Deploy Information Server according to the settings you've defined (`defaults/main.yml` or any usual overrides
    in eg. `host_vars`, `group_vars`, etc)
- Attempt to remove any leftover artifacts for a "clean" and minimal image
- Create a new image called `infosvr` with the tag provided by `tag_name`
- Archive this new image into a tarball in the current directory called `infosvr_<tagname>.tar`

Note that like building any other host, these steps will take some time (more than an hour)...

### Restore an archive into a running container

Run the `restore.yml` playbook provided in this directory as follows (providing the archive filename to `image_filename`):

```bash
$ ansible-playbook -i hosts.container restore.yml -e image_filename=infosvr_<tag>.tar[.gz]
```

(The `-e image_filename=` simply needs to refer to the location of the archived image you want to restore, relative to the path where you are running the playbook.)

This will automatically:

- Restore the archived image back into Docker (including an automatic `gunzip` if it was `gzip`d)
- Startup a new `infosvr` container from this restored image, with the necessary options to run Information Server
- Startup Information Server within the new container

## Detailed explanation

### Build the base image

An SSH key pair is necessary to provide a means of SSH'ing into the container without relying on a static password.
SSH itself is currently needed to run the `IBM.infosvr` Ansible role in order to actually do the installation and
configuration of Information Server.

The following command builds a "base" image for the playbook to run against, with a name of `infosvr_base`:

```bash
$ docker build . -t infosvr_base
```

When finished, you should have an `infosvr_base` image of approximately 400MB:

```bash
$ docker images
REPOSITORY                                 TAG                 IMAGE ID            CREATED              SIZE
infosvr_base                               latest              f89af6c73d6e        About a minute ago   407MB
```

### Startup the base container

Next you'll need to startup the base image as a new container. For DB2 to install, and to "fake" that
we are in fact running Linux and not a container, it is simplest to run this step in `--privileged`
mode.

The following will startup the container, give it a hostname of `infosvr.container.ibm.com`, and map
the SSH entry point to port `22222` on the host machine running Docker (and the web and Kafka ports to
their actual port numbers within the container: `9446` and `59092` respectively).

```bash
$ docker run \
    --name infosvr_build \
    --hostname infosvr.container.ibm.com \
    --publish 22222:22 \
    --publish 59092:59092 \
    --publish 9446:9446 \
    --sysctl kernel.msgmnb=65536 \
    --sysctl kernel.msgmax=65536 \
    --sysctl kernel.shmall=4294967296 \
    --sysctl kernel.msgmni=1024 \
    --sysctl kernel.sem='250 256000 32 1024' \
    --sysctl kernel.shmmni=4096 \
    --sysctl kernel.shmmax=8589934592 \
    --privileged \
    --detach \
    infosvr_base
```

You could of course pick your own port numbers to map to on your Docker host, and a different hostname if
you prefer (as well as a different name for the container). These will be important for the next steps
as inputs to your Ansible inventory and committing a snapshot of the container as a new image.

**Important Note**: Information Server is very sensitive to its hostname, so it is worthwhile picking a
hostname you are happy to stick with -- changing it will mean re-building the image with a new hostname.

Assuming you used the values above, you should now have a running container to build against:

```bash
$ docker ps -a
CONTAINER ID        IMAGE               COMMAND               CREATED             STATUS                      PORTS                                                                     NAMES
585ccce4a0ff        infosvr_base        "/usr/sbin/sshd -D"   3 seconds ago       Up 2 seconds                0.0.0.0:9446->9446/tcp, 0.0.0.0:59092->59092/tcp, 0.0.0.0:22222->22/tcp   infosvr_build
```

### Run the Ansible deployment

Now that you have a running container, you simply need to configure your Ansible inventory to point at that
container:

```ini
[targets]
infosvr.container.ibm.com ansible_user='root' ansible_ssh_private_key_file='~/.ssh/id_rsa' ansible_port=22222 ansible_host=localhost

[ibm-information-server-repo]
infosvr.container.ibm.com

[ibm-information-server-domain]
infosvr.container.ibm.com

[ibm-information-server-engine]
infosvr.container.ibm.com

[ibm-information-server-clients]

[ibm-information-server-ug]

[ibm-cognos-report-server]

[ibm-bpm]
```

This is where the hostname you have chosen in the previous step is important -- it should match what you're entering
as the host in the inventory file. Other important settings are:

- `ansible_host`, which should refer to your Docker host system (eg. `localhost`)
- `ansible_port`, which should refer to the SSH port you mapped during the previous step
- `ansible_ssh_private_key_file`, which should refer to the private key for the public key pair you copied as `id_rsa.pub`
- `ansible_user`, which should remain `root` unless you're modifying the Dockerfile starting point to use another image or user

Once your inventory is setup, run through the playbook execution just as if you were running it against a normal host.

Special notes:

- For some older releases of software like Solr, the Linux version checking relies on `/proc/version`. To "fake"
    the installer(s) into thinking the container is a normal Linux system, bind-mount the provided `proc_version`
    before proceeding. (This is only possible when using `--privileged` above when running the
    container.) While this shouldn't be necessary on any reasonably recent version, it also shouldn't hurt such
    deployments.
- Shutdown the running services within the container in preparation for the next step, so there is a clean point
    from which to do the snapshot.
- Consider removing any leftover artifacts for a "clean" and minimal image for the next step.

### "Snapshot" the container

Like building any other host, that previous step will take some time...

Once completed, though, you'll likely want to "snapshot" your container, so you have a consistent rollback point from
which to run your experiments. You can do this with the following command:

```bash
$ docker commit infosvr_build infosvr:v11.5.0.1
```

Et voila, you now have a container image for that version of Information Server:

```bash
$ docker images
REPOSITORY                                 TAG                 IMAGE ID            CREATED             SIZE
infosvr                                    v11.5.0.1           a2eb5c79c8d8        4 minutes ago       13.7GB
```

### Storing images to avoid auto-pruning

It seems that Docker Desktop (at least on MacOS) may have some auto-prune policy in place, that will remove images that are unused
after some time (as little as 24 hours?). If you plan to save the image you've created, even though you might have removed the 
container, save it into a tarball to avoid losing it to Docker's auto-pruning:

```bash
$ docker image save -o infosvr_v11501.tar infosvr:v11.5.0.1
$ gzip infosvr_v11501.tar
```

(You can then further `gzip` the archive to get down to a more space-efficient 3.2GB archive.)

### Restoring an image

To restore an image from one of the `save`d archives, just use the following (which can take a couple of minutes to complete).

When not `gzip`d (plain `tar` files):

```bash
$ docker load -i infosvr_v11501.tar
5834ef6f70d6: Loading layer [======>                                            ]  1.693GB/13.37GB
```

When `gzip`d:

```bash
$ gunzip -c infosvr_v11501.tar.gz | docker load
5834ef6f70d6: Loading layer [======>                                            ]  1.693GB/13.37GB
```

Aside from displaying a useful progress bar as it loads, this will also restore the image based on the repository, tag and
`ENTRYPOINT` with which it was `save`d along with all of the other metadata from the original `Dockerfile` (ie. the `EXPOSE`d
ports, etc).

### Running a new container from an image

It should be possible to run an image in a new container without still needing `--privileged` mode
(see: https://developer.ibm.com/articles/dm-1602-db2-docker-trs/). However, to succeed you will first need to check and possibly modify your container host's
`sysctl` kernel options as follows:

- `kernel.msgmnb` should be >= `65536`
- `kernel.msgmax` should be >= `65536`
- `kernel.shmall` should be >= `4294967296`
- `kernel.msgmni` should be >= `1024`
- `kernel.sem` should be >= `'250 256000 32 1024'` (ie. each number should be greater than what's listed, and all numbers need to be provided at once in the setting)
- `kernel.shmmni` should be >= `4096`
- `kernel.shmmax` should be >= `8589934592`

Within the Linux host, you can first check the existing value of a parameter using the following command (as root):

```bash
$ sysctl -w kernel.msgmnb
kernel.msgmnb = 65536
```

(Of course replace the parameter with the setting from the list above to check each one.) You only need to modify the settings where the existing value
is less than the suggested value in the list above -- any that are already greater should be left alone.

To modify the parameter, use the command:

```bash
$ sysctl -w kernel.msgmnb=65536
```

Note that on non-Linux systems you'll first need to get into the virtualized Linux host to run these commands -- and furthermore that it seems Docker has recently
changed its setup so that there is no longer any clear way to make these changes survive between restarts of Docker itself. (In other words: you'll need to make 
these changes each time you start, restart, upgrade, etc your Docker installation.)

With Docker Desktop for MacOS this is a matter of:

```bash
$ find ~/Library/Containers/com.docker.docker/Data/ -name 'tty'
/Users/name/Library/Containers/com.docker.docker/Data/vms/0/tty
$ screen ~/Library/Containers/com.docker.docker/Data/vms/0/tty
```

You may then simply see a blank screen: just press enter to get the command prompt within the virtualized Linux host. Once you've completed your
changes, you can exit `screen` by using Ctrl-A Ctrl-\\

(For other host operating systems, please consult stackoverflow or the Docker documentation.)

Once that is configured, you should then be able to run your image as a new container as follows:

```bash
$ docker run \
    --name infosvr \
    --hostname infosvr.container.ibm.com \
    --publish 22222:22 \
    --publish 59092:59092 \
    --publish 9446:9446 \
    --ipc=host \
    --cap-add=IPC_OWNER \
    --detach \
    infosvr:v11.5.0.1
```

**Important notes**:

- you'll need to set the same hostname for the container as was defined when the image was created (Information Server is very sensitive to this)
- the container will only startup SSH -- to run Information Server you'll want to run the `start` tag of this role:

```bash
$ ansible-playbook -i inventory container.yml --tags=start
```

## Other considerations

### Shrinking your image to smallest possible size

Rather than doing the `commit` outlined above, which retains the layers and history, simply do an export as follows
(first pausing the container to avoid any updates while the export is running):

```bash
$ docker pause infosvr_build
$ docker export -o infosvr_v11501.tar infosvr_build
$ gzip infosvr_v11501.tar
```

This will actually skip the creation of an image altogether (so no need to worry separately about that auto-pruning above).

Be aware that as a result of losing the layers and history, however, you will also lose the `ENTRYPOINT` and any repository
and tag information -- so these will need to be added each time you restore the image. In the end, it is probably not worth losing
this metadata just to save a few MB.

To restore an image from one of these `export`ed archives, you would need to use the following command:

```bash
$ gunzip -c infosvr_v11501.tar.gz | docker import --change 'ENTRYPOINT ["/usr/sbin/sshd", "-D"]' - infosvr:v11.5.0.1
```

Note that in this case we need to explicitly provide the repository, tag and `ENTRYPOINT` each time we restore, and all
other metadata from the `Dockerfile` has been lost (so would need to be explicitly added as further `--change` parameters
if needed, on each restore for other settings like `EXPOSE`).

As long as you are happy to provide this extra information each time, and keen to lose the layers and history
to shrink your image, you can skip the `commit` process altogether and just use the trick above to export your built
container straight into a tarball rather than creating an intermediate image.
