ARG OS
ARG OS_VERSION

### SYSTEM BOOTSTRAP ###########################################################
# Clone bootstrap repo instead of using submodules in order to avoid bad git paths
FROM ${OS}:${OS_VERSION} AS dotfiles
ARG BOOTSTRAP_REPO
ARG BOOTSTRAP_BRANCH
SHELL ["/bin/sh", "-ex", "-c"]
WORKDIR /out
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --yes --no-install-recommends \
	ca-certificates \
	git \
DOCKERFILE_EOF
ADD https://api.github.com/repos/$BOOTSTRAP_REPO/git/refs/heads/$BOOTSTRAP_BRANCH /tmp/version.json
RUN git clone https://github.com/$BOOTSTRAP_REPO.git .system-bootstrap
RUN cd .system-bootstrap && git checkout $BOOTSTRAP_BRANCH

### DISCORD.SH #################################################################
FROM ${OS}:${OS_VERSION} AS discord_sh
ARG DISCORD_SH_VERSION
SHELL ["/bin/sh", "-ex", "-c"]
WORKDIR /out
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --yes --no-install-recommends \
	ca-certificates \
	curl
curl -L -o discord.sh https://github.com/fieu/discord.sh/releases/download/$DISCORD_SH_VERSION/discord.sh
chmod a+x discord.sh
DOCKERFILE_EOF

### FINAL IMAGE ################################################################
FROM ${OS}:${OS_VERSION}
SHELL ["/bin/sh", "-ex", "-c"]
ARG USER_PASSWORD

# Install packages
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
# installs needed for other installs
apt-get update
apt-get install --yes --no-install-recommends \
	ca-certificates \
	curl \
	git \
	gzip \
	jq \
	python3 \
	python3-pip \
	ssh-client \
	sudo \
	wget
DOCKERFILE_EOF

# User setup
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
# Create user and group 'unraid-cli' -- since 24.10, 1000:1000 already exists as ubuntu:ubuntu
# Use uid and gid 1000 to match default first-user for linux systems
groupmod --new-name unraid-cli ubuntu
usermod --login unraid-cli --move-home --home /home/unraid-cli --comment "Dockerized Unraid CLI" ubuntu
# Make sure user is in sudoers, temporarily not requiring a password for the docker build
echo "unraid-cli ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/unraid-cli
chmod 0440 /etc/sudoers.d/unraid-cli
# Set password
echo "unraid-cli:${USER_PASSWORD}" | chpasswd
DOCKERFILE_EOF
# Add user PATH dirs
ENV PATH="/home/unraid-cli/.local/bin:${PATH}"

USER unraid-cli:unraid-cli
WORKDIR /home/unraid-cli

# Personal system bootstrap
COPY --from=dotfiles --chown=unraid-cli:unraid-cli /out/.system-bootstrap /home/unraid-cli/.system-bootstrap
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
# USER is needed for bootstrap to work, but it is not set in the docker build
export USER=unraid-cli
# Unraid docker gid
export DOCKER_GID=281
cd ~/.system-bootstrap
./bootstrap --profiles profiles/unraid-cli
DOCKERFILE_EOF

# Finalize user setup
USER root
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
# require password for sudo
chmod u+w /etc/sudoers.d/unraid-cli
sudo echo "unraid-cli ALL=(ALL) ALL" > /etc/sudoers.d/unraid-cli
chmod a-w /etc/sudoers.d/unraid-cli
DOCKERFILE_EOF

COPY src/rootfs /
COPY --from=discord_sh /out/discord.sh /usr/local/bin/discord.sh

USER unraid-cli:unraid-cli
ENTRYPOINT ["/bin/bash"]
