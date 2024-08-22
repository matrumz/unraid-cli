variable os {
	default = {
		name = "ubuntu"
		version = "24.10"
	}
}

variable tool_versions {
	default = {
		discord_sh = "v2.0.0"
	}
}

variable registry {
	default = ""
}

variable image {
	default = "unraid-cli"
}

variable "tags" {
	default = [
		"latest",
	]
}

variable "platforms" {
	default = [
		"linux/amd64",
	]
}

variable "repository" {
	default = "https://github.com/matrumz/unraid-cli"
}

variable "revision" {
	default = ""
}

variable "user_password" {
	// sensitive = true
	default = "pass"
}

variable "bootstrap_repository" {
	default = {
		repository = "matrumz/system-bootstrap-dotbot"
		branch = "master"
	}
}

target "default" {
	dockerfile = "Dockerfile"
	context = "."
	platforms = platforms
	args = {
		"OS" = os.name
		"OS_VERSION" = os.version
		"USER_PASSWORD" = user_password
		"BOOTSTRAP_REPO" = bootstrap_repository.repository
		"BOOTSTRAP_BRANCH" = bootstrap_repository.branch
		"DISCORD_SH_VERSION" = tool_versions.discord_sh
	}
	tags = [for tag in tags : "${registry != "" ? "${registry}/" : ""}${image}:${tag}"]
}
