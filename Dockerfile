ARG OS
ARG OS_VERSION

### SYSTEM BOOTSTRAP ###########################################################
# Clone bootstrap repo instead of using submodules in order to avoid bad git paths
FROM ${OS}:${OS_VERSION} AS dotfiles
ARG BOOTSTRAP_REPO
ARG BOOTSTRAP_BRANCH
SHELL ["/bin/sh", "-e", "-c"]
WORKDIR /out
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
	ca-certificates \
	git \
DOCKERFILE_EOF
ADD https://api.github.com/repos/$BOOTSTRAP_REPO/git/refs/heads/$BOOTSTRAP_BRANCH /tmp/version.json
RUN git clone https://github.com/$BOOTSTRAP_REPO.git .system-bootstrap
# TEMP: use working branch
RUN cd .system-bootstrap && git checkout $BOOTSTRAP_BRANCH

### FINAL IMAGE ################################################################
FROM ${OS}:${OS_VERSION}
SHELL ["/bin/sh", "-e", "-c"]
ARG USER_PASSWORD

# Install packages
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
# installs needed for other installs
apt-get update
apt-get install -y --no-install-recommends \
	ca-certificates \
	curl \
	git \
	gzip \
	python3 \
	python3-pip \
	ssh-client \
	sudo \
	wget
DOCKERFILE_EOF

# User setup
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
# Create user and group 'unraid-cli'
# Use uid and gid 1000 to match default first-user for linux systems
groupadd --gid 1000 unraid-cli
useradd --uid 1000 --gid 1000 --create-home unraid-cli
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
cd ~/.system-bootstrap
set -x
./bootstrap --profiles profiles/unraid-cli
DOCKERFILE_EOF

# Finalize user setup
USER root
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
# require password for sudo
chmod a+w /etc/sudoers.d/unraid-cli
sudo echo "unraid-cli ALL=(ALL) ALL" > /etc/sudoers.d/unraid-cli
chmod a-w /etc/sudoers.d/unraid-cli
DOCKERFILE_EOF
USER unraid-cli:unraid-cli

ENTRYPOINT ["/bin/bash"]
