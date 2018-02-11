#!/bin/bash

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

#: ${2?"Usage: $0 [number of days] [base url of elastic]"}

days=${1}
baseURL=${2}

[ -z "${days}" ] && days=7
[ -z "${baseURL}" ] && baseURL=`hostname`

curl "${baseURL}:32555/_cat/indices?v&h=i" | grep logstash | grep -v monitoring | sort --key=1 | awk -v n=${days} '{if(NR>n) print a[NR%n]; a[NR%n]=$0}' | awk -v baseURL="$baseURL" '{printf "curl -XDELETE '\''%s:32555/%s'\''\n", baseURL, $1}' | while read x ; do eval $x ; done
