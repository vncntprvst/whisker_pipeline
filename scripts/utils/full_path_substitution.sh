#!bin/bash

INPUT_DIR=$1

# check if symlink /om -> /weka/scratch/ exists
if [ -L "/om" ]; then
    om_base_dir=$(readlink -f /om)
    # printf "/om is a symlink to %s\n" "$om_base_dir"
else
    om_base_dir="/om"
fi

if [ -L "/om2" ]; then
    om2_base_dir=$(readlink -f /om2)
    # printf "/om2 is a symlink to %s\n" "$om2_base_dir"
else
    om2_base_dir="/om2"
fi

if [ -L "/om/user/$USER" ]; then
    om_user_dir=$(readlink -f "/om/user/$USER")
    # printf "om user dir ("/om/user/$USER") is a symlink to %s\n" "$om_user_dir"
else
    om_user_dir="$om_base_dir/user/$USER"
fi

if [ -L "/om2/user/$USER" ]; then
    om2_user_dir=$(readlink -f "/om2/user/$USER")
    # printf "om2 user dir ("/om2/user/$USER") is a symlink to %s\n" "$om2_user_dir"
else
    om2_user_dir="$om2_base_dir/user/$USER"
fi

if [ -L "/home" ]; then
    home_user_dir=$(readlink -f "/home/")
    # printf "home user dir ("/home") is a symlink to %s\n" "$home_user_dir"
else
    home_user_dir="/home"
fi

if [ -z "$PARTITION" ]; then
    #  get group of owner of current script
    group=$(stat -c '%G' $0)
    # printf "group of owner of current script: %s\n" "$group"
    # if group is empty, use default group wanglab
    if [ -z "$group" ]; then
        group="wanglab"
    fi
else
    group=$PARTITION
fi

if [ -L "/om/group/$group" ]; then
    om_group_dir=$(readlink -f "/om/group/$group")
    # printf "om group dir ("/om/group/$group") is a symlink to %s\n" "$om_group_dir"
else
    om_group_dir="$om_base_dir/weka/$group/shared"
fi

if [ -L "/om2/group/$group" ]; then
    om2_group_dir=$(readlink -f "/om2/group/$group")
    # printf "om2 group dir ("/om2/group/$group") is a symlink to %s\n" "$om2_group_dir"
else
    om2_group_dir="$om2_base_dir/weka/$group/shared"
fi

# if [ -L "/om/scratch/tmp" ]; then
# # print the target of the symlink
#     om_scratch_dir=$(readlink -f $om_base_dir/scratch/tmp)
#     printf "om scratch dir (/om/scratch/tmp) is a symlink to %s\n" "$om_scratch_dir"
# else
#     om_scratch_dir="$om_base_dir/scratch/tmp"
# fi

if [ -L "/om2/scratch/tmp" ]; then
    om2_scratch_dir=$(readlink -f $om2_base_dir/scratch/tmp)
    # printf "om2 scratch dir (/om2/scratch/tmp) is a symlink to %s\n" "$om2_scratch_dir"
else
    om2_scratch_dir="$om2_base_dir/scratch/tmp"
fi

# directory substitutions:
declare -A substitutions=(
    ["/om/scratch/tmp"]="$om_base_dir/tmp"
    ["/om/user/$USER"]=$om_user_dir         
    ["/om/group/$group"]=$om_group_dir      
    ["/om2/user/$USER"]=$om2_user_dir       
    ["/om2/group/$group"]=$om2_group_dir    
    ["/om2/scratch/tmp"]=$om2_scratch_dir
    ["/home"]=$home_user_dir
)
# Typically:
    # "/om/scratch/tmp"   ->  /weka/scratch/tmp
    # "/om2/scratch/tmp"  ->  /rdma/vast-rdma/scratch/tmp
    # "/om/user/$USER"    ->  /weka/scratch/weka/$group/$USER
    # "/om/group/$group"  ->  /weka/scratch/weka/$group/shared
    # "/om2/user/$USER"   ->  /net/vast-storage/scratch/vast/$group/$USER
    # "/om2/group/$group" ->  /net/vast-storage/scratch/vast/$group/shared

# if $INPUT_DIR contains any of the above, replace it with the corresponding directory
for old in "${!substitutions[@]}"; do
    new=${substitutions[$old]}
    INPUT_DIR=$(echo $INPUT_DIR | sed "s|$old|$new|g")
done

echo $INPUT_DIR