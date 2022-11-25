FROM --platform=linux/amd64 rockylinux:9.0
ARG RELEASE_VERSION="2.6.1"

ARG OS_CODENAME="rocky"
ARG __USER__="root"
ARG __WORK_DIR__="/root"

ENV \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8"

USER ${__USER__}


RUN \
    echo '--> upgrade' && \
    dnf --assumeyes \
        --setopt=tsflags=nodocs \
        upgrade && \
    echo '--> done upgrading' && \
    dnf --assumeyes \
        --setopt=tsflags=nodocs \
        install \
        dnf-utils && \
    dnf --quiet makecache --refresh && \
    echo '--> done upgrading'

RUN	\
    dnf --assumeyes \
        --setopt=tsflags=nodocs \
	    --disableplugin=fastestmirror \
		install \
        openssh-clients-8.7p1-10.el9_0.x86_64 \
        openssh-server-8.7p1-10.el9_0.x86_64 \
        openssl-3.0.1-43.el9_0.x86_64 \
        wget \
        findutils \
 		epel-release \
        sudo && \
    dnf --quiet makecache --refresh && \
    dnf --assumeyes \
        --setopt=tsflags=nodocs \
        --disableplugin=fastestmirror \
        install \
        python3-pip && \
    mkdir -p /var/log/supervisor/ && \
    dnf --assumeyes \
        --setopt=tsflags=nodocs \
        --disableplugin=fastestmirror \
        install \
        git \
        util-linux-user && \
        pip3 install supervisor && \
        pip3 install git+https://github.com/coderanger/supervisor-stdout && \
        dnf --assumeyes \
            erase \
            git


# ------------------------------------------------------------------------------
# Copy files into place
# ------------------------------------------------------------------------------
ADD src /

# ------------------------------------------------------------------------------
# Provisioning
# - UTC Timezone
# - Networking
# - Configure SSH defaults for non-root public key authentication
# - Enable the wheel sudoers group
# - Replace placeholders with values in systemd service unit template
# - Set permissions
# ------------------------------------------------------------------------------
RUN ln -sf \
		/usr/share/zoneinfo/UTC \
		/etc/localtime \
	&& echo "NETWORKING=yes" \
		> /etc/sysconfig/network \
	&& sed -i \
		-e 's~^PasswordAuthentication yes~PasswordAuthentication no~g' \
		-e 's~^#PermitRootLogin yes~PermitRootLogin no~g' \
		-e 's~^#UseDNS yes~UseDNS no~g' \
		-e 's~^\(.*\)/usr/libexec/openssh/sftp-server$~\1internal-sftp~g' \
		/etc/ssh/sshd_config \
	&& sed -i \
		-e 's~^# %wheel\tALL=(ALL)\tALL~%wheel\tALL=(ALL) ALL~g' \
		-e 's~\(.*\) requiretty$~#\1requiretty~' \
		/etc/sudoers \
	&& sed -i \
		-e "s~{{RELEASE_VERSION}}~${RELEASE_VERSION}~g" \
		/etc/systemd/system/centos-ssh@.service \
	&& chmod 644 \
		/etc/{supervisord.conf,supervisord.d/{20-sshd-bootstrap,50-sshd-wrapper}.conf} \
	&& chmod 700 \
		/usr/{bin/healthcheck,sbin/{scmi,sshd-{bootstrap,wrapper},system-{timezone,timezone-wrapper}}}

EXPOSE 22

# ------------------------------------------------------------------------------
# Set default environment variables
# ------------------------------------------------------------------------------
ENV \
	ENABLE_SSHD_BOOTSTRAP="true" \
	ENABLE_SSHD_WRAPPER="true" \
	ENABLE_SUPERVISOR_STDOUT="false" \
	SSH_AUTHORIZED_KEYS="" \
	SSH_CHROOT_DIRECTORY="%h" \
	SSH_INHERIT_ENVIRONMENT="false" \
	SSH_PASSWORD_AUTHENTICATION="false" \
	SSH_SUDO="ALL=(ALL) ALL" \
	SSH_USER="app-admin" \
	SSH_USER_FORCE_SFTP="false" \
	SSH_USER_HOME="/home/%u" \
	SSH_USER_ID="1000:1000" \
	SSH_USER_PASSWORD="" \
	SSH_USER_PASSWORD_HASHED="false" \
	SSH_USER_PRIVATE_KEY="" \
	SSH_USER_SHELL="/bin/bash" \
	SYSTEM_TIMEZONE="UTC"

# ------------------------------------------------------------------------------
# Set image metadata
# ------------------------------------------------------------------------------
LABEL \
	maintainer="James Deathe <james.deathe@gmail.com>" \
	install="docker run \
--rm \
--privileged \
--volume /:/media/root \
jdeathe/centos-ssh:${RELEASE_VERSION} \
/usr/sbin/scmi install \
--chroot=/media/root \
--name=\${NAME} \
--tag=${RELEASE_VERSION} \
--setopt='--volume {{NAME}}.config-ssh:/etc/ssh'" \
	uninstall="docker run \
--rm \
--privileged \
--volume /:/media/root \
jdeathe/centos-ssh:${RELEASE_VERSION} \
/usr/sbin/scmi uninstall \
--chroot=/media/root \
--name=\${NAME} \
--tag=${RELEASE_VERSION} \
--setopt='--volume {{NAME}}.config-ssh:/etc/ssh'" \
	org.deathe.name="centos-ssh" \
	org.deathe.version="${RELEASE_VERSION}" \
	org.deathe.release="jdeathe/centos-ssh:${RELEASE_VERSION}" \
	org.deathe.license="MIT" \
	org.deathe.vendor="jdeathe" \
	org.deathe.url="https://github.com/jdeathe/centos-ssh" \
	org.deathe.description="OpenSSH 7.4 / Supervisor 4.0 / EPEL/IUS/SCL Repositories - CentOS-7 7.6.1810 x86_64."

HEALTHCHECK \
	--interval=1s \
	--timeout=1s \
	--retries=5 \
	CMD ["/usr/bin/healthcheck"]
CMD ["/usr/local/bin/supervisord", "--configuration=/etc/supervisord.conf"]
