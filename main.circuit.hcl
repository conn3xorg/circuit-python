# Facts give each host's distribution, which picks the package name.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }
}

locals {
  # Succeeds when only root can change a path: everything in it, and every
  # directory on the way to it. Add the path after this.
  root_only = "root_only() { p=$(readlink -m -- \"$1\"); [ -z \"$(find \"$p\" \\( ! -uid 0 -o \\( -perm /022 ! -type l \\) \\) -print -quit 2>/dev/null)\" ] || { echo \"$1 can be changed by an account other than root, so root won't run what's in it\" >&2; return 1; }; while [ \"$p\" != / ]; do p=$(dirname -- \"$p\"); [ \"$(stat -c %u -- \"$p\" 2>/dev/null || echo 0)\" = 0 ] && [ $((0$(stat -c %a -- \"$p\" 2>/dev/null || echo 0) & 022)) = 0 ] || { echo \"$p can be changed by an account other than root, so root won't run what's under it\" >&2; return 1; }; done; }; root_only"

  venv_packages = merge([for venv, packages in var.venvs : {
    for name, version in packages : "${venv} ${name}" => { venv = venv, name = name, version = version }
  }]...)
}

circuit "python" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "package" {
    package {
      name = "python3"
    }
  }

  # Debian and Ubuntu split venv and pip's bundled wheel out of python3. The
  # Red Hat family ships them with it.
  step "venv_support" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "python3-venv" : "python3"
    }
  }

  # The check runs pip, not just looks for it, so a venv left behind by a
  # distribution upgrade to a new Python minor release gets rebuilt. Root only
  # runs what's in a venv if no other account can change it or the way to it.
  step "venv" {
    for_each = var.venvs
    command {
      command = "${local.root_only} '${item.key}' || exit 1; /usr/bin/python3 -m venv '${item.key}'"
      unless  = "${local.root_only} '${item.key}' 2>/dev/null && '${item.key}/bin/python' -m pip --version >/dev/null 2>&1"
    }
  }

  step "venv_package" {
    for_each = local.venv_packages
    command {
      command = "${local.root_only} '${item.value.venv}' || exit 1; '${item.value.venv}/bin/python' -m pip install --quiet --disable-pip-version-check '${item.value.name}==${item.value.version}'"
      unless  = "${local.root_only} '${item.value.venv}' 2>/dev/null && '${item.value.venv}/bin/python' -c 'import importlib.metadata as m, sys; sys.exit(m.version(sys.argv[1]) != sys.argv[2])' '${item.value.name}' '${item.value.version}' 2>/dev/null"
    }
  }
}
