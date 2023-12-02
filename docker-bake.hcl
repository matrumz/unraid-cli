variable os {
	default = {
		"name" = "debian"
		"version" = "12"
	}
}

variable tool_versions {
	default = {
	}
}

variable registry {
	default = "devola:5000"
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

target "default" {
	dockerfile = "Dockerfile"
	context = "."
	platforms = platforms
	args = {
		"OS" = os.name
		"OS_VERSION" = os.version
	}
	tags = [for tag in tags : "${registry != "" ? "${registry}/" : ""}${image}:${tag}"]
}
