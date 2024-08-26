# This script sets global variables used in the preprocessing pipeline. It is
# run by other scripts in the pipeline. 

#  Try to source the server directories
if [ -f ./secrets/server_dirs.sh ]; then
    source ./secrets/server_dirs.sh
elif [ -f ../secrets/server_dirs.sh ]; then
    source ../secrets/server_dirs.sh
else
    echo "File server_dirs.sh not found."
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

echo -e '\n'
echo -e "\e[33mSet user variables\e[0m"

echo -e "\e[1m\e[37mUSERNAME: $USERNAME\e[0m"
echo -e "\e[1m\e[37mPROJECT: $PROJECT\e[0m"
echo -e "\e[1m\e[37mOM_USERNAME: $OM_USERNAME\e[0m"
echo -e "\e[1m\e[37mEMAIL: $EMAIL\e[0m"
echo -e "\e[1m\e[37mPARTITION: $PARTITION\e[0m"

echo -e '\n'
echo -e "\e[33mSet directories\e[0m"

echo -e "\e[1m\e[37mSTORE_BASE_DIR: $STORE_BASE_DIR\e[0m"
echo -e "\e[1m\e[37mPROC_BASE_DIR: $PROC_BASE_DIR\e[0m"
echo -e "\e[1m\e[37mPIPELINE_CODE_DIR: $PIPELINE_CODE_DIR\e[0m"

echo -e '\n'