# In a container (EXPERIMENTAL)

These are purely experimental instructions for building a Docker container using this Ansible role.

This is neither in any way supported, nor in any way following best practices for this kind of approach;
however, if you're after a consistent rollback point for some quick experimentation (without needing to
keep a large VM around), this could be useful.

## Build the base image

1. Copy a public key over that you would like to use for accessing your container via SSH into `id_rsa.pub`,
    inside this directory.
1. Run the following command to build a "base" image for the playbook to run against:

    ```bash
    $ docker build . -t infosvr_base
    ```

You should now have an `infosvr_base` image of approximately 400MB:

```bash
$ docker images
REPOSITORY                                 TAG                 IMAGE ID            CREATED              SIZE
infosvr_base                               latest              f89af6c73d6e        About a minute ago   407MB
```

## Startup the base container

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

## Run the Ansible deployment

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

### Optimised deployment

Alternatively, use the `container.yml` playbook provided in this directory to run through an optimised deployment:

- For some older releases of software like Solr, the Linux version checking relies on `/proc/version`. To "fake"
    the installer(s) into thinking the container is a normal Linux system, this playbook bind-mounts the provided
    `proc_version` before proceeding. (This is only possible when using `--privileged` above when running the
    container.) While this shouldn't be necessary on any reasonably recent version, it also shouldn't hurt such
    deployments.
- This playbook will also go through and attempt to remove any leftover artifacts for a "clean" and minimal
    image for the next step.

Note that this will leave the container in a completely shutdown (probably safest) state for the image step below;
however, this does mean you need to run the startup yourself (eg. `ansible-playbook -i inventory container.yml --tags=start`)
any time you create a new container with the image.

## "Snapshot" the container

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

## Other tips and tricks

### Storing images to avoid auto-pruning

It seems that Docker Desktop (at least on MacOS) may have some auto-prune policy in place, that will remove images that are unused
after some time (as little as 24 hours?). If you plan to save the image you've created, even though you might have removed the 
container, save it into a tarball to avoid losing it to Docker's auto-pruning:

```bash
$ docker image save -o infosvr_v11501.tar infosvr:v11.5.0.1
$ gzip infosvr_v11501.tar
```

(You can then further `gzip` the archive to get down to a more space-efficient 3.2GB archive.)

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
and tag information -- so these will need to be added each time you restore the image.

### Restoring an image

To restore an image from one of the `save`d archives, just use the following (which can take a couple of minutes to complete):

```bash
$ gunzip -c infosvr_v11501.tar.gz | docker load
5834ef6f70d6: Loading layer [======>                                            ]  1.693GB/13.37GB
```

Aside from displaying a useful progress bar as it loads, this will also restore the image based on the repository, tag and
`ENTRYPOINT` with which it was `save`d along with all of the other metadata from the original `Dockerfile` (ie. the `EXPOSE`d
ports, etc).

To restore an image from one of the `export`ed archives, use the following similar command with some additions:

```bash
$ gunzip -c infosvr_v11501.tar.gz | docker import --change 'ENTRYPOINT ["/usr/sbin/sshd", "-D"]' - infosvr:v11.5.0.1
```

Note that in this case we need to explicitly provide the repository, tag and `ENTRYPOINT` each time we restore, and all
other metadata from the `Dockerfile` has been lost (so would need to be explicitly added as further `--change` parameters
if needed, on each restore).

However, as long as you are happy to provide this extra information each time, and keen to lose the layers and history
to shrink your image, you can skip the `commit` process altogether and just use the trick above to export your built
container straight into a tarball rather than creating an intermediate image.

### Running a new container from an image

You can then at any point create a new container from your already-built image using the following -- which avoids
running in `--privileged` mode:

```bash
$ docker run \
    --name infosvr \
    --hostname infosvr.container.ibm.com \
    --publish 22222:22 \
    --publish 59092:59092 \
    --publish 9446:9446 \
    --ipc host \
    --cap-add IPC_OWNER \
    --detach \
    infosvr:v11.5.0.1
```

(See: https://developer.ibm.com/articles/dm-1602-db2-docker-trs/)

**Important notes**:

- you'll need to set the same hostname for the container as was defined when the image was created (Information Server is very sensitive to this)
- you'll still need to run the container with the extra options for `ipc` and `cap-add`; otherwise DB2 will not run (and therefore none of the rest of the stack, either)
- (if you run into issues, you may want to skip these new options and revert back to `--privileged` and the various `--sysctl` parameters)
- the container will only startup SSH -- to run Information Server you'll want to run the `start` tag of this role:

```bash
$ ansible-playbook -i inventory container.yml --tags=start
```
