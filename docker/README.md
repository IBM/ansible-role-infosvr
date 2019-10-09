# In a Docker container (EXPERIMENTAL)

These are purely experimental instructions for building a Docker container using this Ansible role.

This is neither in any way supported, nor necessarily following best practices for this kind of approach;
however, if you're after a consistent rollback point for some quick experimentation (without needing to
keep a large VM around), this could be useful.

**Important**: as with any use of licensed commercial software

- be very careful not to push any such container into a public repository!
- check with your IBM Representative for details on any license entitlement questions or concerns

## Prerequisites

- [Docker](http://docker.com) pre-installed
- This repository cloned
- Your entitled IBM InfoSphere Information Server media files downloaded and available locally

## Building a re-usable container

### Step 0: Picking a foundational image

To ensure the IBM Information Server services automatically startup when creating or restarting a container, it is best
to use a `systemd`-capable base image: for example `registry.redhat.io/rhel7-init`. The choice of foundational image
is up to you, given that some (like the one mentioned) will require licenses, subscriptions, etc.

Ensure that the image has been setup ready-to-use, including activating any necessary subscription.

(In the example above, this would require creating a derived container image after running `subscription-manager`
inside the a container running the vanilla image, and then `docker commit`ing the results into a new derived
container image.)

The next step by default assumes you've named this derived image `rhel7-systemd-base`.

### Step 1: Building a base image

This image builds from your choice of foundational image above by loading the minimal system packages and Ansible roles
needed to do the installation of IBM Information Server.

To build the base image, change into the `container` subdirectory of this repository and first modify the `FROM` line of
the `Dockerfile` to reflect your derived container image from the previous step.

Then execute the following:

```bash
$ docker build --rm -t infosvr_base .
```

After a minute or two you should have a new image called `infosvr_base`:

```bash
$ docker images
REPOSITORY                                 TAG                 IMAGE ID            CREATED             SIZE
infosvr_base                               latest              91c56796b63b        6 minutes ago       529MB
```

This base image simply has the foundational elements for actually deploying an Information Server environment into
a container -- it has not yet actually built an Information Server container.

### Step 2: Configuring your Information Server deployment

Using the `vars.yml` file in the `container` sub-directory as a starting point, override any variables the Ansible
role uses that you want to be used as part of your particular configuration. Once happy with the configuration,
copy this file into the media directory on your local (host) machine: that is, the directory where the IBM InfoSphere
Information Server software install binaries are located. Leave the filename as `vars.yml`.

These overrides will then be applied automatically picked up and applied in the next step.

(If you do not provide any overrides, the default values from `defaults/main.yml` of the role will be used.)

### Step 3: Start a base image for deployment

To actually run through the Information Server deployment into the image, you will need to run the container with a
number of options:

- The `hostname` should be set to a consistent value that you plan to use long-term for the container. Information
    Server tends not to work if you change an environment's hostname after installation, so it is best to pick
    something now that you plan to stick with whenever running the container in the future. It is also advisable to
    use a single simple name, *not* a dot-separated fully-qualified name, if you ever plan to make use of this image
    in a Kubernetes cluster (since k8s will have its own DNS suffixes, namespaces, etc).
- The volume where your IBM InfoSphere Information Server installation media sits in your local machine must be
    mounted to the directory `/mnt/media` within the container. You can mount it read-only to ensure none of the
    media is changed or removed from your local system.
- To ensure the embedded DB2 can be installed and run without issues, you need to run the container with `host` IPC
    mode and with the `IPC_OWNER` capability added. You should also ensure that your host system has appropriate
    settings for the various `sysctl` parameters listed further below.
- To ensure that `systemd` will work as expected, you'll also need to add the `SYS_ADMIN` capability, mount the
    `/sys/fs/cgroup` directory into your container, and the `/run` tmpfs directory.

```bash
$ docker run \
    --ipc=host \
    --cap-add=IPC_OWNER \
    --hostname infosvr \
    --volume /sys/fs/cgroup:/sys/fs/cgroup \
    --volume ~/Developer/media:/mnt/media:ro \
    --tmpfs /run \
    -P \
    -d \
    --name infosvr_build \
    infosvr_base
```

In this example we use the hostname `infosvr` and our local directory containing the software is `~/Developer/media`,
which we are mounting into the running container in read-only mode. (The `ipc` and `cap-add` arguments ensure we have
the appropriate parameters for installing and running DB2.) **Important note**: if you opt to use a hostname *other
than* `infosvr`, please also change the `local_connection` and `infosvr` files in the `container` directory *before*
running the very first build step in this process.

### Step 4: Run the Information Server deployment

Once the base image is up and running, execute the deployment of IBM Information Server within it using the following
command:

```bash
$ docker exec infosvr_build /bin/bash -c "screen -dmLS install sh -c 'ansible-playbook /root/playbooks/build.yml --extra-vars @/mnt/media/vars.yml'"
```

This will begin automatically installing and deploying IBM InfoSphere Information Server into the container. You can
view the progress of the installation using the following command from outside the docker container:

```bash
$ docker exec infosvr_build tail -F /screenlog.0

PLAY [IBM InfoSphere Information Server] ***************************************
...
```

This simply tails the log of the Ansible role running within the container itself. (Simply press `Ctrl-C` to exit
from the logs, without impacting the install itself.)

Note that this process will take some time: likely 1 hour or more. In particular, tasks like the installation of the
domain tier take a very long time. If you want to monitor the status of such installs in more detail while they are
running (to distinguish whether they are still running or have hit some error that is hanging any further progress),
login to an interactive shell within the container and tail any files in the `/tmp/ibm_is_logs/` directory:

```bash
$ docker exec -it infosvr_build /bin/bash
[root@infosvr /]# tail -f /tmp/ibm_is_logs/*
...
```

This will give you a running output of the underlying Information Server installation logs, each of which should
indicate successful completion (eventually) when each tier is successfully installed; something along these lines:

```text
2019-02-25T13:39:07.441, INFO: The installation Engine completed all steps successfully. Total elapsed time: 212,853 ms.
```

If you see an exception stack trace and `SEVERE` or `FATAL` errors, then most likely something has gone wrong in the
installation. Note that once a given tier completes installing, you may need to `Ctrl-C` to exit out of the `tail`
process, and then run the same `tail -f ...` command again to get a refreshed list of log files for the other
tier(s) that are being installed. (There could also be a few seconds to a minute delay between the tiers themselves
installing.)

When successfully completed, you should see the `completed all steps successfully` message from three separate
log files, and the following output in the overall log (`docker exec infosvr_build tail -F /screenlog.0` output):

```text
PLAY RECAP *********************************************************************
localhost                  : ok=214  changed=54   unreachable=0    failed=0

Monday 25 February 2019  17:34:22 +0000 (0:00:00.074)       0:53:10.577 *******
```

This indicates the number of tasks carried out (`ok`, `changed`, etc) and the overall time it took to do the deployment
is given in the lower-right (just over 53 minutes in the example above).

If you entered an interactive shell within the container to view the more detailed logs, just type `exit` to close
out of that interactive session.

### Step 5: Tagging your deployed image for later re-use

Rather than needing to go through this hour(s)-long second step each time you want to make use of a container
running the software, you'll probably want to tag this image for later re-use. Before doing so, it will be best to
shutdown the various services running in the container to ensure everything is in a consistent state. You can do
this by running the following command (from outside the container):

```bash
$ docker exec infosvr_build sh -c 'ansible-playbook /root/playbooks/ops.yml --tags=stop'
...
PLAY RECAP *********************************************************************
localhost                  : ok=22   changed=0    unreachable=0    failed=0
```

Before committing all of these changes directly, though, you will likely want to do some cleanup to free up as
much space as possible. I would suggest removing the following:

- `/opt/IBM/InformationServer/isdump-redhat-*`
- `/opt/IBM/InformationServer/Updates/Downloads`
- `/opt/IBM/InformationServer/Updates/Backup.*`
- `/opt/IBM/InformationServer/Updates/_jvm.*`
- `/opt/IBM/InformationServer/Updates/server.*`
- `/opt/IBM/InformationServer/_uninstall/Backup.*`
- `/opt/IBM/InformationServer/_uninstall/_jvm.*`
- `/opt/IBM/InformationServer/_uninstall/server.*`
- `/tmp/*`

You can do this by once again logging in to an interactive shell in the container:

```bash
$ docker exec -it infosvr_build /bin/bash
[root@infosvr /]# rm -rf /tmp/*
...
[root@infosvr /]# shutdown -h now
```

(Of course, if you want any other change to consistently be available on each fresh startup of the image in a
new container -- such as enabling events -- feel free to make that change now as well.)

Once happy with the image state, you can commit this massive set of changes into a single layer using a command
like the following:

```bash
$ docker commit \
    infosvr_build \
    localhost:5000/infosvr:v11.7.0.2
```

To avoid any clashes with running a fresh container (see troubleshooting section on mixed shared memory),
you should probably stop and remove the build container at this point:

```bash
$ docker stop infosvr_build
infosvr_build
$ docker rm infosvr_build
infosvr_build
```

### Step 5: Running a new container from your saved image

Now that you've waited all that time to build such an image above, you should be able to re-use it without
going through all of that again by simply running the following any time you want to run a container:

```bash
$ docker run \
    --ipc=host \
    --cap-add=IPC_OWNER \
    --hostname infosvr \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --tmpfs /run \
    -p 9446:9446 \
    -d \
    localhost:5000/infosvr:v11.7.0.2
```

(And of course, you should be able to make use of the container through Kubernetes as well, just be sure that
your k8s spec includes the IPC mode, capabilities, and hostname as required by the command above.)

### Step 6: Shutting down / removing the container

While you can simply do a `docker stop` and removal, because the container has been running in the `host` IPC
mode it may leave behind a number of shared objects if not shutdown cleanly. To shut down the container cleanly,
run the following:

```bash
$ docker exec -it <container_name> /bin/bash
[root@infosvr /]# ansible-playbook /root/playbooks/ops.yml --tags=stop
...
PLAY RECAP *********************************************************************
localhost                  : ok=21   changed=0    unreachable=0    failed=0

Monday 25 February 2019  22:08:18 +0000 (0:00:01.357)       0:00:45.490 *******
===============================================================================
...
[root@infosvr /]# shutdown -h now
```

If you forget, you can always follow the instructions in troubleshooting below regarding mixed up shared memory
to manually clean up any objects left behind.

## Troubleshooting

### Ensure your host is setup to be able to run the container

It should be possible to run an image in a new container without needing `--privileged` mode
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
$ sysctl kernel.msgmnb
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

### Examining the logs, if there was any error that stopped or froze the installation

The log files for the installation are all under `/tmp/ibm_is_logs` within the container. If for some reason your installation
process has frozen or stalled, feel free to login to a TTY within your container and examine these logs for exception stack
traces or other information to help you understand what may have gone wrong:

```bash
$ docker exec -it infosvr_build /bin/bash
[root@infosvr /]# tail -f /tmp/ibm_is_logs/*
...
```

If you think you've fixed the issue and want to try your luck at re-running the deployment (this is unlikely to be successful,
more likely to be successful if you correct the underlying problem and start-over with a new container):

```bash
[root@infosvr /]# screen -r
```

From here you can also try re-running the deployment from within the container by using the following command:

```bash
[root@infosvr /]# ansible-playbook /root/playbooks/build.yml
```

To exit `screen` without cancelling the deployment, press `Ctrl-A d`, and then you can simply
type `exit` to logout of the docker TTY you opened with the first command.

### Mixed up shared memory

Note that because the container needs to run with the host's IPC namespace, it will not be possible to run multiple containers at the same time.
(In particular, the DataStage portion of the image will require specifically-named semaphores and shared memory segments which will clash between
multiple running instances by default, and you may run into problems with DB2 starting up if it has some previous remnants still lurking around
in these namespaces.)

If you accidentally try to run multiple Information Server containers at the same time, you will likely leave behind some stale shared objects
in the host's IPC.

You can check this by logging in to your host (see sample instructions for doing this under the first troubleshooting section) and running the
following command:

```bash
$ ipcs -a

------ Message Queues --------
key        msqid      owner      perms      used-bytes   messages

------ Shared Memory Segments --------
key        shmid      owner      perms      bytes      nattch     status

------ Semaphore Arrays --------
key        semid      owner      perms      nsems

```

The output shown above is for a clean host, without any stale shared objects. If you see various objects listed, particularly if the `owner`
shows as simply a number (a UID) rather than a name, it is likely that these were left behind by some container and not properly cleaned up.

You can remove them from your host using the `ipcrm` command -- but be careful, as removing objects that are in use by the system, host, or
some other container could damage your host, containers, etc!
