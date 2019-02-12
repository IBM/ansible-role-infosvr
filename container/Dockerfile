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

FROM centos:7

# Add base packages needed by Information Server, SSH and Python (needed for remote configuration by ansible)
RUN yum install -y initscripts chkconfig which lsof openssh-server python python-lxml python-jmespath sudo file libselinux-python unzip glibc.i686 libstdc++.i686 libXp libXau libXext libX11 libxcb libgcc.i686 libXmu pam.i686 net-tools bind-utils nss-softokn-freebl bc libaio compat-libstdc++-33 libXtst elfutils ed util-linux-ng gcc gcc-c++ perl && yum clean all

# Copy a Linux look-a-like version
COPY proc_version /root/proc_version

# Configure SSH
RUN mkdir /root/.ssh && chmod 755 /root/.ssh && sshd-keygen -A
COPY id_rsa.pub /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# Expose SSH, web console / API port, and Kafka port
EXPOSE 22 9446 59092

# Launch SSH
ENTRYPOINT ["/usr/sbin/sshd", "-D"]
