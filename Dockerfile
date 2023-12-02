ARG OS
ARG OS_VERSION

### SYSTEM BOOTSTRAP ###########################################################
# Clone bootstrap repo instead of using submodules in order to avoid bad git paths
FROM ${OS}:${OS_VERSION} AS dotfiles
SHELL ["/bin/sh", "-e", "-c"]
WORKDIR /out
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
	git
git clone git@github.com:matrumz/system-bootstrap-dotbot.git
DOCKERFILE_EOF

### FINAL IMAGE ################################################################
FROM ${OS}:${OS_VERSION}
SHELL ["/bin/sh", "-e", "-c"]
ARG OS
ARG OS_VERSION

# Install packages
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive

# installs needed for other installs
apt-get update
apt-get install -y --no-install-recommends \
	ca-certificates \
	curl \
	gnupg \
	gpg \
	gzip \
	sudo \
	wget

# Add fish repo
case "${OS}" in
	"debian")
		cat <<EOF >> /etc/apt/sources.list.d/shells:fish:release:3.list
deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_${OS_VERSION}/ /
EOF
		curl -fsSL https://download.opensuse.org/repositories/shells:fish:release:3/Debian_${OS_VERSION}/Release.key | gpg --dearmor > /etc/apt/trusted.gpg.d/shells_fish_release_3.gpg
		;;
	*)
		echo "Unsupported OS: ${OS}"
		exit 1
		;;
esac

# Add docker repo
case "${OS}" in
	"debian")
		sudo install -m 0755 -d /etc/apt/keyrings
		curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
		sudo chmod a+r /etc/apt/keyrings/docker.gpg
		echo \
			"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
			$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
			sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		;;
	*)
		echo "Unsupported OS: ${OS}"
		exit 1
		;;
esac

# desired apt package installs
apt-get update
apt-get install -y --no-install-recommends \
	docker-buildx-plugin /
	docker-ce-cli /
	docker-compose-plugin /
	fish /
	git /
	tmux /
	vim

# OMF
curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish

DOCKERFILE_EOF
# /Install packages

# Create user and group 'unraid-cli' with uid and gid 1000
RUN <<DOCKERFILE_EOF
export DEBIAN_FRONTEND=noninteractive
groupadd --gid 1000 unraid-cli
useradd --uid 1000 --gid 1000 --create-home --shell /usr/bin/fish unraid-cli
DOCKERFILE_EOF

USER unraid-cli:unraid-cli

# Fish personalizations
RUN <<DOCKERFILE_EOF
fish --command "omf install default"
fish --command "omf install z"
DOCKERFILE_EOF

COPY --from=dotfiles /out/system-bootstrap-dotbot /home/unraid-cli/.system-bootstrap

