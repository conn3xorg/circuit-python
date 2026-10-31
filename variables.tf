variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "venvs" {
  type        = map(map(string))
  default     = {}
  description = "Virtual environments to create, by absolute path, each with the packages to install from PyPI at exact versions, such as { \"/opt/tools\" = { cowsay = \"6.1\" } }."

  validation {
    condition     = alltrue([for path in keys(var.venvs) : can(regex("^/[A-Za-z0-9._/-]*[A-Za-z0-9._-]$", path))])
    error_message = "Each key of venvs must be an absolute path, such as \"/opt/tools\"."
  }

  validation {
    condition     = alltrue(flatten([for packages in values(var.venvs) : [for name in keys(packages) : can(regex("^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$", name))]]))
    error_message = "Each package name in venvs must be a PyPI project name, such as \"cowsay\"."
  }

  validation {
    condition     = alltrue(flatten([for packages in values(var.venvs) : [for v in values(packages) : can(regex("^[0-9][0-9A-Za-z.!+-]*$", v))]]))
    error_message = "Each version in venvs must be exact, such as \"6.1\", not a range."
  }
}
