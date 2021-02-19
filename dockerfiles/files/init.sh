#!/bin/sh
# ------------------------------------------------------------------------
# Copyright 2018 WSO2, Inc. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
# ------------------------------------------------------------------------

set -e

# volume mounts
config_volume=${WORKING_DIRECTORY}/wso2-config-volume
original_deployment_artifacts=${WORKING_DIRECTORY}/wso2-tmp/server
deployment_volume=${WSO2_SERVER_HOME}/repository/deployment/server

# capture Docker container IP from the container's /etc/hosts file
#docker_container_ip=$(awk 'END{print $1}' /etc/hosts)

# check if the WSO2 non-root user home exists
test ! -d ${WORKING_DIRECTORY} && echo "WSO2 Docker non-root user home does not exist" && exit 1

# check if the WSO2 product home exists
test ! -d ${WSO2_SERVER_HOME} && echo "WSO2 Docker product home does not exist" && exit 1

# if a deployment_volume is present and empty, copy original deployment artifacts to server...
# copying original artifacts to ${WORKING_DIRECTORY}/wso2-tmp/server was already done in the Dockerfile
# these artifacts will be copied to deployment_volume if it is empty, before the server is started
if test -d ${original_deployment_artifacts}; then
    if [ -z "$(ls -A ${deployment_volume}/)" ]; then
	    # if no artifact is found under <WSO2_SERVER_HOME>/repository/deployment/server; copy originals
	    echo "Copying original deployment artifacts from temporary location to server..."
	    cp -R ${original_deployment_artifacts}/* ${deployment_volume}/
    fi
fi

FILES="./ca/*"
for f in $FILES
do
  filename=$(basename -- "$f")
  filename="${filename%.*}"
  echo "Processing $filename file..."
  keytool -import -alias $filename -file $f -keystore ${WSO2_SERVER_HOME}/repository/resources/security/client-truststore.jks -storepass ${APIM_KEYSTORE_PASS:-wso2carbon} -noprompt
  keytool -list -keystore ${WSO2_SERVER_HOME}/repository/resources/security/client-truststore.jks -alias $filename -storepass ${APIM_KEYSTORE_PASS:-wso2carbon} -noprompt
done

# copy any configuration changes mounted to config_volume
test -d ${config_volume}/ && cp -RL ${config_volume}/* ${WSO2_SERVER_HOME}/
bash ${WORKING_DIRECTORY}/dss-config.sh
# start WSO2 Carbon server
sh ${WSO2_SERVER_HOME}/bin/wso2server.sh
