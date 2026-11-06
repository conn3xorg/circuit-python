variable "port" {
  type    = number
  default = 2333
}

# CI sets this to an older cowsay first, then upgrades the venv by applying
# again with the default.
variable "cowsay_version" {
  type    = string
  default = "6.1"
}

module "python" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  venvs = { "/opt/cowsay" = { cowsay = var.cowsay_version } }
}

output "python" {
  value = module.python.python
}
