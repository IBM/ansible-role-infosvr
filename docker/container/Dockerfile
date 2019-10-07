###
# Copyright 2018 IBM Corp. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###

FROM rhel7-systemd-base

VOLUME [ "/sys/fs/cgroup" ]

# Add base packages needed by Information Server and Ansible
RUN yum install -y initscripts chkconfig which lsof screen openssl python python-lxml python-jmespath python-setuptools sudo file libselinux-python unzip glibc.i686 libXp libXau libXext libX11 libxcb libXmu pam.i686 net-tools bind-utils nss-softokn-freebl bc libaio numactl-libs compat-libstdc++-33 libXtst elfutils ed util-linux-ng gcc gcc-c++ perl less git && \
        yum clean all && \
        yum install -y libstdc++.i686 libgcc.i686 && \
        yum clean all && \
        easy_install pip && \
        pip install ansible && \
        pip install jmespath

# Configure defaults for connections, etc
COPY ansible.cfg /etc/ansible/
COPY local_connection /etc/ansible/inventories/
COPY infosvr /etc/ansible/inventories/
COPY build.yml /root/playbooks/
COPY ops.yml /root/playbooks/

RUN ansible-galaxy install IBM.infosvr && \
        ansible-galaxy install IBM.infosvr-metadata-asset-manager && \
        ansible-galaxy install IBM.infosvr-import-export && \
        ansible-galaxy install IBM.infosvr-openigc

# Expose web console / API, Zookeeper and Kafka ports
EXPOSE 9446 52181 59092
