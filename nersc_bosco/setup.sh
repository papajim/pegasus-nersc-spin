#!/usr/bin/env bash

source setup.conf

work_dir=`pwd`

#### Create ssh key for BOSCO using sshproxy ####
if [ -z $NERSC_USER ]; then
   NERSC_USER=$USER
fi

if [ ! -z $NERSC_SSH_PROXY ]; then
   if [ -z $NERSC_SSH_SCOPE ]; then
      $NERSC_SSH_PROXY -u $NERSC_USER -o ~/.ssh/bosco_key.rsa
   else
      $NERSC_SSH_PROXY -u $NERSC_USER -s $NERSC_SSH_SCOPE -o ~/.ssh/bosco_key.rsa
   fi
else
   sftp $NERSC_USER@cori.nersc.gov:/project/projectdirs/mfa/NERSC-MFA/sshproxy.sh $work_dir/helpers/sshproxy.sh
   NERSC_SSH_PROXY="$work_dir/helpers/sshproxy.sh"
   if [ -z $NERSC_SSH_SCOPE ]; then
      $NERSC_SSH_PROXY -u $NERSC_USER -o ~/.ssh/bosco_key.rsa
   else
      $NERSC_SSH_PROXY -u $NERSC_USER -s $NERSC_SSH_SCOPE -o ~/.ssh/bosco_key.rsa
   fi
fi

#### Check if bosco_key.rsa exists in ~/.ssh ####
if [ -f ~/.ssh/bosco_key.rsa ]; then
cat <<EOF >> ~/.ssh/config
Host cori*.nersc.gov
    User $NERSC_USER
    IdentityFile $HOME/.ssh/bosco_key.rsa
EOF
else
   echo "BOSCO ssh key is not available"
   exit
fi

#### start bosco ####
#bosco_start

#### register nersc endpoint ####
bosco_cluster --platform RH6 --add $NERSC_USER@cori.nersc.gov slurm

#### stop bosco ####
#bosco_stop

#### Install Pegasus glite attributes ####
#### Install openssl libraries ####
ssh -i ~/.ssh/bosco_key.rsa $NERSC_USER@cori.nersc.gov <<EOF
$NERSC_PEGASUS_HOME/bin/pegasus-configure-glite ~/bosco/glite
ln -s /global/common/software/m2187/shared_libraries/openssl/lib/libcrypto.so.1.0.0 ~/bosco/glite/lib/libcrypto.so.10
ln -s /global/common/software/m2187/shared_libraries/openssl/lib/libssl.so.1.0.0 ~/bosco/glite/lib/libssl.so.10
EOF

#### Install edited glite scripts ####
cd $work_dir
sftp -i ~/.ssh/bosco_key.rsa $NERSC_USER@cori.nersc.gov <<EOF
put config/glite/bin/* bosco/glite/bin
put config/glite/etc/* bosco/glite/etc
EOF
