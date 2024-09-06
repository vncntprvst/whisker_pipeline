# This script sets global variables used in the preprocessing pipeline. It is
# run by other scripts in the pipeline. 

TERM=xterm-256color

#  Try to source the server directories
if [ -f ./secrets/server_dirs.sh ]; then
    source ./secrets/server_dirs.sh
elif [ -f ../secrets/server_dirs.sh ]; then
    source ../secrets/server_dirs.sh
else
    echo -e "\e[31mError:\e[0m File \e[37;103mserver_dirs.sh\e[0m not found \n" 
fi

# Enable the module command if not already enabled
if ! command -v module &> /dev/null
then
    source /etc/profile.d/modules.sh
fi

export BASE_PWD=`pwd`

# Set LOGIN_NAME to first argument passed. If empty, set to $USER
LOGIN_NAME="${1:-$USER}"

echo "LOGIN_NAME: $LOGIN_NAME"

export PROJECT="whisker_asym"
export DLC_NETWORK="face_poke-Vincent-2024-02-29"
export OM_USERNAME=$LOGIN_NAME
export EMAIL="$USER@mit.edu"
export PARTITION=$(groups | awk '{print $1}')

if [ "$LOGIN_NAME" == "prevosto" ]; then
    # User variables
    export USERNAME="Vincent"
    # Base directories
    export OM_BASE_DIR=$OM_USER_DIR_ALIAS/$USER/data
    export OM2_BASE_DIR=$OM2_USER_DIR_ALIAS/$USER/data
    export NESE_BASE_DIR=$NESE_LAB_DIR/$USERNAME/Ephys
    export OM_SCRATCH_DIR=$OM_SCRATCH_TMP/$USERNAME
    export OM2_SCRATCH_DIR=$OM2_SCRATCH_TMP/$USERNAME
    export SCRATCH_ROOT="$(dirname "$OM_SCRATCH_DIR")"
    # Assign directories
    export STORE_BASE_DIR=$NESE_BASE_DIR
    export PROC_BASE_DIR=$OM_SCRATCH_DIR #$OM_BASE_DIR
    export PIPELINE_CODE_DIR=$OM_USER_DIR_ALIAS/$USER/code/whisker_pipeline
    
elif [ "$LOGIN_NAME" == "mg2k" ]; then
    # User variables
    export USERNAME="Mel"
    # Base directories
    export OM_BASE_DIR=$OM_USER_DIR_ALIAS/$USER/data
    export OM2_BASE_DIR=$OM2_USER_DIR_ALIAS/$USER/data
    export NESE_BASE_DIR=$NESE_LAB_DIR/$USERNAME/Ephys
    export OM_SCRATCH_DIR=$OM_SCRATCH_TMP/$USERNAME
    export OM2_SCRATCH_DIR=$OM2_SCRATCH_TMP/$USERNAME
    export SCRATCH_ROOT="$(dirname "$OM_SCRATCH_DIR")"
    # Assign directories
    export STORE_BASE_DIR=$NESE_BASE_DIR
    export PROC_BASE_DIR=$OM_SCRATCH_DIR #$OM_BASE_DIR
    export PIPELINE_CODE_DIR=$OM_USER_DIR_ALIAS/$USER/code/whisker_pipeline

elif [ "$LOGIN_NAME" == "wanglab" ]; then
    # User variables
    export USERNAME=$USER
    # Base directories
    export BACKUP_DIR=/mnt/f
    export ANALYSIS_DIR=/mnt/e
    # Assign directories
    export STORE_BASE_DIR=$BACKUP_DIR
    export PROC_BASE_DIR=$ANALYSIS_DIR
    export PIPELINE_CODE_DIR=/home/$LOGIN_NAME/code/whisker_pipeline
else
    # User variables
    export USERNAME=$USER
fi

# if HPCC_IMAGE_REPO path exists, set IMAGE_REPO to it, otherwise set it to the default (../containers/)
if [ -d "${HPCC_IMAGE_REPO}" ]; then
    IMAGE_REPO=$HPCC_IMAGE_REPO
else
    IMAGE_REPO=$PWD/../containers/
fi
if [ -f ../utils/full_path_substitution.sh ]; then 
    export IMAGE_REPO=$(bash ../utils/full_path_substitution.sh $IMAGE_REPO)
elif [ -f ./utils/full_path_substitution.sh ]; then
    export IMAGE_REPO=$(bash ./utils/full_path_substitution.sh $IMAGE_REPO)
else
    echo -e "\e[31mError:\e[0m File \e[37;103mfull_path_substitution.sh\e[0m not found \n"
fi

if [ -f ../utils/find_os_type.sh ]; then 
    output=$(bash ../utils/find_os_type.sh)
elif [ -f ./utils/find_os_type.sh ]; then
    output=$(bash ./utils/find_os_type.sh)
else
    echo -e "\e[31mError:\e[0m File \e[37;103mfind_os_type.sh\e[0m not found \n"
fi
export OS_VERSION=$(echo "$output" | grep OS_VERSION | cut -d ' ' -f 2)

echo -e '\n'
echo -e "\e[4m\e[35mUser variables\e[0m"
echo -e "LOGIN_NAME: \e[1m\e[95m$LOGIN_NAME\e[0m"
echo -e "USERNAME: \e[1m\e[95m$USERNAME\e[0m"
echo -e "PROJECT: \e[1m\e[95m$PROJECT\e[0m"
echo -e "OM_USERNAME: \e[1m\e[95m$OM_USERNAME\e[0m"
echo -e "EMAIL: \e[1m\e[95m$EMAIL\e[0m"
echo -e "PARTITION: \e[1m\e[95m$PARTITION\e[0m"

# echo -e '\n'
echo -e "\e[4m\e[35mWorking directories\e[0m"
echo -e "STORE_BASE_DIR: \e[1m\e[95m$STORE_BASE_DIR\e[0m"
echo -e "PROC_BASE_DIR: \e[1m\e[95m$PROC_BASE_DIR\e[0m"
echo -e "PIPELINE_CODE_DIR: \e[1m\e[95m$PIPELINE_CODE_DIR\e[0m"
echo -e "IMAGE_REPO: \e[1m\e[95m $IMAGE_REPO\e[0m" 
echo -e "OS_VERSION: \e[1m\e[95m$OS_VERSION\e[0m"

echo -e '\n'