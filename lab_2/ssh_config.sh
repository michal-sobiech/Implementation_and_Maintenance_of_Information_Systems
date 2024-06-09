#!/bin/bash

$VM_IP=$1
$SSH_KEY_DIR='~/.ssh/wus_ansible'
$SSH_PRIV_KEY_NAME='id_rsa'

SSH_PRIV_KEY_ABS_PATH="$SSH_KEY_DIR/$SSH_PRIV_KEY_NAME"

if [ -z $(ls -A $SSH_PRIV_KEY_ABS_PATH) ]; then
    ssh-keygen -t rsa -b 2048 -f $SSH_PRIV_KEY_ABS_PATH
fi

ssh-copy-id -i $SSH_PRIV_KEY_ABS_PATH.pub Username@$VM_IP

