# ansible-role-infosvr

Ansible role for automating the deployment of an IBM InfoSphere Information Server environment, including:

- the repository (database) tier
- domain (services) tier
- engine tier

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
- Machine Learning Term Classification (v11.7+)

Currently the deployment only caters for DB2 as the back-end, though works for both installing and configuring the bundled DB2 as well as configuring a pre-existing DB2. Either a full WebSphere Application Server Network Deployment configuration or a WebSphere Liberty Profile configuration will be installed (see variables below for more details); currently the role is not able to configure a pre-existing WebSphere installation.

## Requirements

- Ansible v2.4.x
- 'root'-become-able network access all servers
- Administrator-access to Windows client machine(s)
- Windows client machine(s) configured for WinRM access by Ansible (see http://docs.ansible.com/ansible/latest/intro_windows.html)

## Role Variables

See `defaults/main.yml` for inline documentation, and the example below for the main variables needed. The defaults file contains the default settings you would find for a vanilla v11.7 installation already, so you only need to override those variables for which you do not wish to use the default (ie. passwords for users).

The minimal variables that likely need to be overridden are as follows:

- `ibm_infosvr_media_dir`: the location on your Ansible host where the installation binaries have already been downloaded (eg. from Passport Advantage)
- `ibm_infosvr_media_bin` dict: the names of the binaries to use for the installation (by default the vanilla v11.7 files are there; if you want to install v11.5 these need to be replaced with the v11.5 file names)
- `ibm_infosvr_ug_storage`: the extra, raw storage device on the Unified Governance tier to be used by kubernetes (should be raw: unmounted, not in an lvm group, etc)
- `ibm_infosvr_features` dict: defining the features you want (True) vs do not want (False)

Finally, the various credentials variables should be overridden to create a sufficiently secure environment.  Searching for `_upwd_` will reveal all of the password variables in the `defaults/main.yml` that you will want to override.

## Dependencies

The configuration of Information Analyzer makes use of the `IBM.infosvr-metadata-asset-manager` role indirectly, using the `import_role` directive.  Therefore `IBM.infosvr-metadata-asset-manager` is not explicitly in the dependencies of this role, but it does need to be installed for this role to work (if you are installing and configuring the Information Analyzer feature).

## Example Playbook

The following example playbook will do a complete installation and configuration of IBM InfoSphere Information Server using the default parameters from `defaults/main.yml` (and any overrides you've placed in eg. `group_vars/all.yml`). Note that because the entire installation is done across multiple tiers by this single role, you should use `any_errors_fatal` to avoid partial install / configuration of a tier in the event an earlier step fails on a different tier.

```yml
- name: install and configure IBM InfoSphere Information Server
  hosts:
    - ibm-information-server-repo
    - ibm-information-server-domain
    - ibm-information-server-engine
    - ibm-information-server-clients
    - ibm-information-server-ug
  any_errors_fatal: true
  roles:
    - ibm-infosvr
```

## Expected Inventory

The following groups are expected in the inventory, as they are used to distinguish where various components are installed. Of course, if you want to install multiple components on a single server this can be done by simply providing the same hostname under each group. In the example below, for instance, the repository and domain tiers are both placed on 'serverA' while the engine tier will be installed separately on 'serverB' and the Unified Governance tier is also given its own system 'serverC'.

```ini
[ibm-information-server-repo]
# Linux host where the repository tier (database) should be installed (DB2)
serverA.somewhere.com

[ibm-information-server-domain]
# Linux host where the domain (services) tier should be installed (WebSphere)
serverA.somewhere.com

[ibm-information-server-engine]
# Linux host where the engine tier should be installed
serverB.somewhere.com

[ibm-information-server-clients]
# Windows host where the client applications should be installed, and a Metadata Interchange Server configured for Windows-only brokers / bridges
client.somewhere.com

[ibm-information-server-ug]
# Linux host where the v11.7+ Unified Governance tier shuold be installed (kubernetes)
serverC.somewhere.com

[ibm-information-server-external-db]
# Linux host that holds a pre-existing database into which to deploy XMETA, etc -- if no host provided, or this group is missing entirely, will install the bundled DB2 onto ibm-information-server-repo server
serverD.somewhere.com

[ibm-cognos-report-server]
# Linux host where a pre-existing Cognos BI installation exists (for Information Governance Dashboard)
cognos.somewhere.com

[ibm-bpm]
# Linux host where a pre-existing BPM installation exists (currently unused)
bpm.somewhere.com
```

As with any Ansible inventory, sufficient details should be provided to ensure connectivity to the servers is possible (see http://docs.ansible.com/ansible/latest/intro_inventory.html#list-of-behavioral-inventory-parameters).

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
