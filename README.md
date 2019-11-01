# ansible-role-infosvr

Ansible role for automating the deployment of an IBM InfoSphere Information Server environment, both versions 11.5 and 11.7, including:

- the repository (database) tier
- domain (services) tier
- engine tier
- unified governance ("Enterprise Search") tier (v11.7 only)
- patches / fixpacks

and the following modules of Enterprise Edition, which can be disabled through the variables described below (eg. if not entitled to use them or you do not want to install / configure them):

- Information Governance Catalog
- Information Analyzer
- DataStage Operations Console
- DataClick
- Event Management (integration to Data Quality Exception Console)
- Data Quality Exception Console
- QualityStage
- Information Services Director
- FastTrack
- Information Governance Dashboard (requires a pre-existing Cognos environment)
- Optim Masking within DataStage
- Including these extras only available in v11.7:
  - New Information Governance Catalog (UI)
  - Governance Monitor dashboards
  - Enterprise Search (including Knowledge Graph)
  - DataStage Flow Designer
  - Machine Learning Term Classification (v11.7+)

Currently the deployment only caters for DB2 as the back-end, though works for both installing and configuring the bundled DB2 as well as configuring a pre-existing DB2. Either a full WebSphere Application Server Network Deployment configuration or a WebSphere Liberty Profile configuration will be installed (see variables below for more details); currently the role is not able to configure a pre-existing WebSphere installation.

New to Ansible? This [simple introduction](https://cmgrote.github.io/ansible-tutorial/) might help.

## Requirements

- Ansible v2.7
- 'root'-become-able network access all servers
- Administrator-access to Windows client machine(s)
- Windows client machine(s) configured for WinRM access by Ansible (see http://docs.ansible.com/ansible/latest/intro_windows.html)

## Role Variables

See `defaults/main.yml` for inline documentation, and the example below for the main variables needed. The defaults file contains the default settings you would find for a vanilla v11.7 installation already, so you only need to override those variables for which you do not wish to use the default (ie. passwords for users).

The minimal variables that likely need to be overridden are as follows:

- `ibm_infosvr_media_dir`: the location on your Ansible host where the installation binaries have already been downloaded (eg. from Passport Advantage)
- `ibm_infosvr_media_bin` dict: the names of the binaries to use for the installation (by default the latest available v11.7 files are there; if you want to install v11.5 these need to be replaced with the v11.5 file names)
- `ibm_infosvr_ug_storage`: the extra, raw storage device on the Unified Governance tier to be used by kubernetes (should be raw: unmounted, not in an lvm group, etc)
- `ibm_infosvr_features` dict: defining the features you want (True) vs do not want (False)

Finally, the various credentials variables should be overridden to create a sufficiently secure environment.  Searching for `_upwd_` will reveal all of the password variables in the `defaults/main.yml` that you will want to override.  (And feel free to replace this with references to other variables which are themselves further secured through an Ansible vault.)

## Dependencies

The configuration of Information Analyzer makes use of the [`IBM.infosvr-metadata-asset-manager`](https://galaxy.ansible.com/IBM/infosvr-metadata-asset-manager) role indirectly, using the `import_role` directive. This role has not been listed as an explicit dependency to avoid circular dependencies, but it should be installed if you plan to configure Information Analyzer.

## Example Playbook

The following example playbook will do a complete installation and configuration of IBM InfoSphere Information Server using the default parameters from `defaults/main.yml` (and any overrides you've placed in eg. `group_vars/all.yml`). Note that because the entire installation is done across multiple tiers by this single role, you should use `any_errors_fatal` to avoid partial install / configuration of a tier in the event an earlier step fails on a different tier.

```yml
---

- name: install and configure IBM InfoSphere Information Server
  hosts: all
  any_errors_fatal: true
  roles:
    - IBM.infosvr
  pre_tasks:
    - name: update all OS-level packages
      yum:
        state: latest
        name: '*'
        exclude: docker*,kubelet*,kubectl*,kubeadm*
      become: yes
      when: ('ibm_information_server_clients' not in group_names)
```

The pre-tasks ensure that all OS-level packges are up-to-date before beginning the installation.

## Expected Inventory

The following groups are expected in the inventory, as they are used to distinguish where various components are installed. Of course, if you want to install multiple components on a single server this can be done by simply providing the same hostname under each group. In the example below, for instance, the repository and domain tiers are both placed on 'serverA' while the engine tier will be installed separately on 'serverB' and the Unified Governance tier is also given its own system 'serverC'.

```ini
[ibm_information_server_repo]
# Linux host where the repository tier (database) should be installed (DB2)
serverA.somewhere.com

[ibm_information_server_domain]
# Linux host where the domain (services) tier should be installed (WebSphere)
serverA.somewhere.com

[ibm_information_server_engine]
# Linux host where the engine tier should be installed
serverB.somewhere.com

[ibm_information_server_clients]
# Windows host where the client applications should be installed, and a Metadata Interchange Server configured for Windows-only brokers / bridges
client.somewhere.com

[ibm_information_server_ug]
# Linux host where the v11.7+ Unified Governance tier shuold be installed (kubernetes)
serverC.somewhere.com

[ibm_information_server_external_db]
# Linux host that holds a pre-existing database into which to deploy XMETA, etc -- if no host provided, or this group is missing entirely, will install the bundled DB2 onto ibm_information_server_repo server
serverD.somewhere.com

[ibm_cognos_report_server]
# Linux host where a pre-existing Cognos BI installation exists (for Information Governance Dashboard)
cognos.somewhere.com

[ibm_bpm]
# Linux host where a pre-existing BPM installation exists (currently unused)
bpm.somewhere.com
```

As with any Ansible inventory, sufficient details should be provided to ensure connectivity to the servers is possible (see http://docs.ansible.com/ansible/latest/intro_inventory.html#list-of-behavioral-inventory-parameters).

## Tags

### Installing patches

The role is intended to also be able to keep an installed environment up-to-date with patches and system packages. To apply patches, simply enter the relevant details into the files under `vars/patches/[server|client]/<version>/<date>.yml`. For example, fixes for v11.7.1.0 server-side should go into `vars/patches/server/11.7.1.0/<date>.yml` while fixes for v11.7.0.2 client-side go into `vars/patches/client/11.7.0.2/<date>.yml`, where `<date>` is the date on which the patch was released. Generally these are kept up-to-date within GitHub based on the availability of major patches in Fix Central; but should you wish to apply an interim fix or other that is not already in the list, simply follow the instructions below.

- Each patch should be a dictionary named `ibm_infosvr_patch_definition`.
- The dictionary should contain the following keys:
  - `name`: the name of the patch / fixpack, as listed on IBM Fix Central
  - `srcFile`: the name of the patch / fixpack file, as downloaded from IBM Fix Central
  - `pkgFile`: the name of the `.ispkg` file contained within the `srcFile`
  - `versionId`: the `installerId` tag that is added to your Version.xml once the patch / fixpack is installed
  - `tiers`: a list of the tiers on which this patch should be applied (possible values are `domain` and `engine`) -- for the client patches, this is implied to be client, so no `tiers` is needed

For example:

```yml
ibm_infosvr_patch_definition:
  name: is11700_ServicePack2_ug_services_engine_linux64
  srcFile: servicepack_11.7_SP2_linux64_11700.tar.gz
  pkgFile: servicepack_11.7_SP2_linux64_11700.ispkg
  versionId: servicepack_SP2_IS117_11700
  tiers:
    - domain
    - engine
```

JDK updates can also be included under `vars/patches/jdk/[server|client]/<major>/latest.yml`, where `<major>` is the major release version (`11.5` or `11.7`). In both cases, a single dictionary named `ibm_infosvr_jdk_definition` should be used to define the JDK information.

For `11.5` the following keys are needed:

- `name`: the name of the JDK, as listed on IBM Fix Central
- `infosvr_filename`: the name of the JDK file, as downloaded from IBM Fix Central
- `infosvr_extract_path`: the path created by extracting the JDK file
- `versionInfo`: the version string that uniquely identifies this version of the JDK (from `java -version`)
- `was_filename`: the name of the WebSphere Application Server (WAS) fixpack that contains the v6 JDK
- `was_offering`: the name of the offering within the WAS JDK (v6) fixpack
- `jdk7_filename`: the name of the WAS fixpack that contains the v7 JDK
- `jdk7_offering`: the name of the offering within the WAS JDK (v7) fixpack
- `was_versionInfo`: the version string that uniquely identifies this version of the JDK (v6, from `java -version`)
- `jdk7_versionInfo`: the version string that uniquely identifies this version of the JDK (v7, from `java -version`)

For `11.7` the following keys are needed:

- `name`: the name of the JDK, as listed on IBM Fix Central
- `infosvr_filename`: the name of the JDK file, as downloaded from IBM Fix Central
- `infosvr_extract_path`: the path created by extracting the JDK file
- `was_filename`: the name of the WebSphere Application Server (WAS) fixpack that contains the JDK
- `was_offering`: the name of the offering within the WAS JDK fixpack
- `versionInfo`: the version string that uniquely identifies this version of the (non-WAS) JDK (from `java -version`)
- `was_versionInfo`: the version string that uniquely identifies this version of the (WAS) JDK (from `java -version`)

These JDK updates are not a list, but a simple dictionary -- because each update will overwrite the previous update, you should only ever need to list the latest version of the JDK you wish to apply.

To run through an update, use the `update` tag as follows:

```shell
ansible-playbook [-i hosts] [site.yml] --tags=update
```

This will apply any patches listed in the `vars/patches...` files for your particular release that have not already been applied. The patches are applied in sorted order, based on the date on which they were released (oldest first). It will *not* however update any system-level packages for the operating system: if this is desired, ensure your broader playbook takes care of such an update.

### Environment operations

A number of tags have been provided to ease the operations of the environment, particularly when it spans multiple hosts:

- `status`: will check that the various components that have been configured are running (by checking that a service is listening on their designated ports).
- `stop`: will gracefully shutdown each component, in the appropriate order, across the various hosts; without shutting down the underlying hosts themselves.
- `start`: will startup each component, in the appropriate order, across the various hosts.
- `restart`: provides a simple way to run a `stop` followed immediately by a `start`.

## Re-usable tasks

The role also includes the following re-usable tasks, meant for inclusion in other roles that need to make use of the characteristics of the Information Server installation without necessarily running through all of the installation steps themselves.

### setup_vars.yml

The configuration variables used in deploying an Information Server environment can be retrieved later by using the `setup_vars.yml` set of tasks, for example by including the following play in your playbook:

```yml
---

- name: setup Information Server vars
  hosts: all
  tasks:
    - import_role: name=IBM.infosvr tasks_from=setup_vars.yml
```

### get_certificate.yml

The root SSL certificate of the domain tier of an Information Server environment can be retrieved later by using the `get_certificate.yml` set of tasks, for example by including the following play in your playbook:

```yml
---

- name: setup Information Server vars
  hosts: all
  tasks:
    - import_role: name=IBM.infosvr tasks_from=setup_vars.yml
    - import_role: name=IBM.infosvr tasks_from=get_certificate.yml
```

Note that this set of tasks depends on the `setup_vars.yml` being run already as well, so it may be worth including them in the same play (as in the example above). The domain tier's SSL certificate will be stored into `cache/__ibm_infosvr_cert_root.crt` relative to the path where the playbook is executing on the control machine.

## License

Apache 2.0

## Author Information

Christopher Grote
