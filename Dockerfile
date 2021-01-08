FROM centos:centos7

#### ENV Variables For Packages ####
ENV PEGASUS_VERSION "pegasus-5.0.0"
ENV PEGASUS_VERSION_NUM "5.0.0"
ENV BOSCO_VERSION_NUM "1.2.12"

#### ENV Variables For User and Group ####
ENV USER "papajim"
ENV USER_GROUP "m2187"
ENV HOME "/home/${USER}"
ENV NERSC_HOME "/global/homes/p/papajim/${USER}"

#### Change to user 0 ####
#USER 0

#### Update Packages ####
RUN yum -y update

#### Install basic packages ####
RUN yum -y install which java-1.8.0-openjdk-devel sudo mysql-devel postgresql-devel epel-release vim python python3 openssh-clients libgomp rsync perl perl-Data-Dumper

RUN pip3 install --upgrade pip && pip3 install pyyaml gitpython

#### Add automation user ####
RUN groupadd -g 62982 ${USER_GROUP} && \
    useradd -s /bin/bash -u 74935 -g 62982 -m ${USER} && \
    mkdir -p $HOME/.ssh && chmod 700 $HOME/.ssh && chown ${USER}:${USER_GROUP} $HOME/.ssh

#### Install Pegasus from tarball ####
RUN curl -o /opt/${PEGASUS_VERSION}.tar.gz http://download.pegasus.isi.edu/pegasus/${PEGASUS_VERSION_NUM}/pegasus-binary-${PEGASUS_VERSION_NUM}-x86_64_rhel_7.tar.gz && \
    tar -xzvf /opt/${PEGASUS_VERSION}.tar.gz -C /opt && \
    rm /opt/${PEGASUS_VERSION}.tar.gz && \
    chown ${USER}:${USER_GROUP} -R /opt/${PEGASUS_VERSION}

ENV PATH "/opt/${PEGASUS_VERSION}/bin:$PATH"
ENV PYTHONPATH "/opt/${PEGASUS_VERSION}/lib64/python3.6/site-packages:/opt/${PEGASUS_VERSION}/lib64/pegasus/externals/python:$PYTHONPATH"
ENV PERL5LIB "/opt/${PEGASUS_VERSION}/lib64/pegasus/perl:$PERL5LIB"

#### Install and configure BOSCO ####
RUN curl -o /opt/boscoinstaller.tar.gz ftp://ftp.cs.wisc.edu/condor/bosco/${BOSCO_VERSION_NUM}/boscoinstaller.tar.gz && \
    tar -xzvf /opt/boscoinstaller.tar.gz -C /opt && \
    /opt/boscoinstaller --prefix=/opt/bosco --owner=${USER} && \
    rm /opt/boscoinstaller && rm /opt/boscoinstaller.tar.gz && \
    chown ${USER}:${USER_GROUP} -R /opt/bosco

#### Comment out copy of key to authorized keys ####
RUN for lnum in {829..834}; do sed -i "${lnum}s/\(.*\)/#\1/" /opt/bosco/bin/bosco_cluster; done

#### Add bosco helpers to the container    ####
RUN mkdir /opt/nersc_bosco && mkdir /opt/nersc_bosco/helpers && \
    echo "NERSC_USER=${USER}" > /opt/nersc_bosco/setup.conf && \
    echo "NERSC_PEGASUS_HOME=/global/common/software/m2187/pegasus/stable" >> /opt/nersc_bosco/setup.conf && \
    echo "NERSC_SSH_SCOPE=${USER_GROUP}" >> /opt/nersc_bosco/setup.conf
COPY nersc_bosco /opt/nersc_bosco
RUN chown ${USER}:${USER_GROUP} -R /opt/nersc_bosco

RUN echo "#!/bin/bash" > /opt/entrypoint.sh && \
    echo "mv /opt/bosco/local.* /opt/bosco/local.\$HOSTNAME" >> /opt/entrypoint.sh && \
    echo "sed -i \"s/LOCAL_CONFIG_FILE.*/LOCAL_CONFIG_FILE = \/opt\/bosco\/local.\$HOSTNAME\/condor_config.local/\" /opt/bosco/etc/condor_config" >> /opt/entrypoint.sh && \
    echo "sed -i \"s/CONDOR_HOST.*/CONDOR_HOST = \$HOSTNAME/\" /opt/bosco/etc/condor_config" >> /opt/entrypoint.sh && \
    echo "sed -i \"s/COLLECTOR_NAME.*/COLLECTOR_NAME = Personal Condor at \$HOSTNAME/\" /opt/bosco/etc/condor_config" >> /opt/entrypoint.sh && \
    echo "source /opt/bosco/bosco_setenv" >> /opt/entrypoint.sh && \
    echo "bosco_start" >> /opt/entrypoint.sh && \
    echo "while true; do sleep 60; done" >> /opt/entrypoint.sh && \
    chown ${USER}:${USER_GROUP} /opt/entrypoint.sh && chmod +x /opt/entrypoint.sh

COPY sns-namd-shifter-example.tar.gz /home/${USER}
RUN cd /home/${USER} && \
    tar -xzvf sns-namd-shifter-example.tar.gz && \
    rm -rf /home/${USER}/sns-namd-shifter-example.tar.gz && \
    chown ${USER}:${USER_GROUP} -R ${HOME}

USER ${USER}
RUN echo "source /opt/bosco/bosco_setenv" >> ${HOME}/.bashrc

ENTRYPOINT [ "/opt/entrypoint.sh" ]
