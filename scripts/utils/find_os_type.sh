#!bin/bash

# Determine if os is centos7 or rocky8

# Read the ID and VERSION_ID from /etc/os-release
. /etc/os-release

# Extract the major version number from VERSION_ID
MAJOR_VERSION=${VERSION_ID%%.*}

# Check if the OS is CentOS 7
if [ "$ID" = "centos" ] && [ "$MAJOR_VERSION" = "7" ]; then
    echo "The operating system is CentOS 7."
    OS_VERSION="centos7"
# Check if the OS is Rocky 8 (or any later version)
elif [ "$ID" = "rocky" ] && [ "$MAJOR_VERSION" = "8" ]; then
    echo "The operating system is Rocky 8."
    OS_VERSION="rocky8"
else
    echo "The operating system is $ID $VERSION_ID."
fi

echo "OS_VERSION: $OS_VERSION"