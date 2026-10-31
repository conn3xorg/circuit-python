variable "port" {
  type    = number
  default = 2333
}

module "python" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  venvs = { "/opt/cowsay" = { cowsay = "6.1" } }
}

output "python" {
  value = module.python.python
}
