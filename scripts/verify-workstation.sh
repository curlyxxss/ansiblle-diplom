#!/usr/bin/env bash

set -euo pipefail

STATUS_OK=0
STATUS_WARN=0
STATUS_FAIL=0

log_section() {
  echo
  echo "============================================================"
  echo " $*"
  echo "============================================================"
}

ok() {
  STATUS_OK=$((STATUS_OK + 1))
  echo "[OK]   $*"
}

warn() {
  STATUS_WARN=$((STATUS_WARN + 1))
  echo "[WARN] $*"
}

fail() {
  STATUS_FAIL=$((STATUS_FAIL + 1))
  echo "[FAIL] $*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

find_command() {
  local cmd="$1"
  local candidate

  if command -v "${cmd}" >/dev/null 2>&1; then
    command -v "${cmd}"
    return 0
  fi

  for candidate in "/usr/sbin/${cmd}" "/sbin/${cmd}" "/usr/bin/${cmd}" "/bin/${cmd}"; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  return 1
}

check_command() {
  local description="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    ok "${description}"
  else
    fail "${description}"
  fi
}

get_os_info() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_NAME="${PRETTY_NAME:-unknown}"
    OS_ID="${ID:-unknown}"
  else
    OS_NAME="unknown"
    OS_ID="unknown"
  fi
}

require_root_or_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=""
  elif command_exists sudo; then
    SUDO="sudo"
  else
    fail "sudo is not available and script is not running as root"
    exit 1
  fi
}

check_basic_system() {
  log_section "Basic system checks"

  ok "Hostname: $(hostname)"
  ok "Current user: $(whoami)"
  ok "OS: ${OS_NAME}"

  if command_exists timedatectl; then
    timedatectl_status="$(timedatectl 2>/dev/null | grep 'Time zone' || true)"
    if [[ -n "${timedatectl_status}" ]]; then
      ok "${timedatectl_status}"
    else
      warn "Could not read timezone using timedatectl"
    fi
  else
    warn "timedatectl is not available"
  fi

  if command_exists locale; then
    locale_lang="$(locale | grep '^LANG=' || true)"
    if [[ -n "${locale_lang}" ]]; then
      ok "Locale: ${locale_lang}"
    else
      warn "LANG locale is not set"
    fi
  else
    warn "locale command is not available"
  fi
}

check_users() {
  log_section "Users and sudo checks"

  if getent passwd ansible >/dev/null; then
    ok "User 'ansible' exists"
  else
    fail "User 'ansible' does not exist"
  fi

  if getent passwd developer >/dev/null; then
    DEV_USER="developer"
    ok "User 'developer' exists"
  elif getent passwd devuser >/dev/null; then
    DEV_USER="devuser"
    ok "User 'devuser' exists"
  else
    DEV_USER=""
    fail "Developer user does not exist"
  fi

  if id ansible 2>/dev/null | grep -qE '\b(sudo|wheel)\b'; then
    ok "User 'ansible' is in sudo/wheel group"
  else
    fail "User 'ansible' is not in sudo/wheel group"
  fi

  if [[ -f /etc/sudoers.d/ansible ]]; then
    if ${SUDO} visudo -cf /etc/sudoers.d/ansible >/dev/null 2>&1; then
      ok "Sudoers file for 'ansible' is valid"
    else
      fail "Sudoers file for 'ansible' is invalid"
    fi
  else
    if sudo -n true >/dev/null 2>&1; then
      ok "Sudoers file for 'ansible' is not present, but passwordless sudo works"
    else
      fail "Sudoers file for 'ansible' is missing and passwordless sudo does not work"
    fi
  fi

  if ${SUDO} passwd -S ansible 2>/dev/null | grep -q ' L '; then
    ok "Password for 'ansible' is locked"
  else
    warn "Password for 'ansible' is not locked or status is unknown"
  fi

  if [[ -n "${DEV_USER}" ]]; then
    if ${SUDO} passwd -S "${DEV_USER}" 2>/dev/null | grep -q ' L '; then
      ok "Password for '${DEV_USER}' is locked"
    else
      warn "Password for '${DEV_USER}' is not locked or status is unknown"
    fi

    if [[ -f "/etc/sudoers.d/${DEV_USER}" ]]; then
      warn "Sudoers file for '${DEV_USER}' exists"
    else
      ok "No sudoers file for '${DEV_USER}'"
    fi
  fi
}

check_ssh_security() {
  log_section "SSH security checks"

  local sshd_bin=""
  local ssh_service=""
  local sshd_config_file="/etc/ssh/sshd_config"
  local sshd_config=""

  if sshd_bin="$(find_command sshd 2>/dev/null)"; then
    if ${SUDO} "${sshd_bin}" -t >/dev/null 2>&1; then
      ok "SSH server configuration syntax is valid"
    else
      fail "SSH server configuration syntax is invalid"
    fi

    sshd_config="$(${SUDO} "${sshd_bin}" -T 2>/dev/null || true)"
  else
    if systemctl list-unit-files ssh.service >/dev/null 2>&1 || systemctl status ssh >/dev/null 2>&1; then
      ssh_service="ssh"
      warn "sshd command is not available; checking ssh service and sshd_config file directly"
    else
      fail "Neither sshd command nor ssh service is available"
      return
    fi

    if systemctl is-enabled "${ssh_service}" >/dev/null 2>&1; then
      ok "ssh service is enabled"
    else
      warn "ssh service is not enabled"
    fi

    if systemctl is-active "${ssh_service}" >/dev/null 2>&1; then
      ok "ssh service is active"
    else
      fail "ssh service is not active"
    fi

    if [[ -f "${sshd_config_file}" ]]; then
      ok "SSH config file exists: ${sshd_config_file}"
      sshd_config="$(awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        {
          key=tolower($1)
          $1=""
          sub(/^[[:space:]]+/, "")
          print key " " tolower($0)
        }
      ' "${sshd_config_file}")"
    else
      fail "SSH config file is missing: ${sshd_config_file}"
      return
    fi
  fi

  check_sshd_value() {
    local key="$1"
    local expected="$2"

    if echo "${sshd_config}" | grep -qi "^${key} ${expected}$"; then
      ok "SSH ${key} = ${expected}"
    else
      fail "SSH ${key} is not '${expected}'"
    fi
  }

  check_sshd_value "permitrootlogin" "no"
  check_sshd_value "passwordauthentication" "no"
  check_sshd_value "pubkeyauthentication" "yes"
  check_sshd_value "permitemptypasswords" "no"
  check_sshd_value "x11forwarding" "no"

  if echo "${sshd_config}" | grep -qi '^allowtcpforwarding no$'; then
    ok "SSH allowtcpforwarding = no"
  else
    warn "SSH allowtcpforwarding is not 'no'"
  fi

  if echo "${sshd_config}" | grep -qi '^allowusers '; then
    ok "SSH AllowUsers is configured: $(echo "${sshd_config}" | grep -i '^allowusers ' | tr '\n' ' ')"
  else
    warn "SSH AllowUsers is not configured; this is acceptable when security_ssh_allow_users is empty"
  fi

  if echo "${sshd_config}" | grep -qi '^maxauthtries '; then
    ok "SSH MaxAuthTries is configured"
  else
    warn "SSH MaxAuthTries is not configured"
  fi

  if echo "${sshd_config}" | grep -qi '^maxsessions '; then
    ok "SSH MaxSessions is configured"
  else
    warn "SSH MaxSessions is not configured"
  fi

  if echo "${sshd_config}" | grep -qi '^maxstartups '; then
    ok "SSH MaxStartups is configured"
  else
    warn "SSH MaxStartups is not configured"
  fi
}
check_fail2ban() {
  log_section "Fail2ban checks"

  if ! command_exists fail2ban-client; then
    fail "fail2ban-client is not installed"
    return
  fi

  if systemctl is-enabled fail2ban >/dev/null 2>&1; then
    ok "fail2ban service is enabled"
  else
    warn "fail2ban service is not enabled"
  fi

  if systemctl is-active fail2ban >/dev/null 2>&1; then
    ok "fail2ban service is active"
  else
    fail "fail2ban service is not active"
  fi

  if ${SUDO} fail2ban-client status 2>/dev/null | grep -q 'sshd'; then
    ok "fail2ban sshd jail is configured"
  else
    fail "fail2ban sshd jail is not configured"
  fi
}

check_firewall() {
  log_section "Firewall checks"

  local ufw_bin=""

  if ! ufw_bin="$(find_command ufw 2>/dev/null)"; then
    fail "ufw is not installed"
    return
  fi

  ok "ufw is installed: ${ufw_bin}"
  ufw_status="$(${SUDO} "${ufw_bin}" status verbose 2>/dev/null || true)"

  if echo "${ufw_status}" | grep -qi '^Status: active'; then
    ok "ufw is active"
  else
    fail "ufw is not active"
  fi

  if echo "${ufw_status}" | grep -qi 'Default: deny (incoming), allow (outgoing)'; then
    ok "ufw default policy is deny incoming / allow outgoing"
  else
    warn "ufw default policy is not expected"
  fi

  if echo "${ufw_status}" | grep -Eq '22/tcp|22'; then
    ok "SSH port is allowed in ufw"
  else
    warn "SSH port 22 is not explicitly shown in ufw rules"
  fi
}

check_sysctl() {
  log_section "Sysctl hardening checks"

  local sysctl_bin=""

  if ! sysctl_bin="$(find_command sysctl 2>/dev/null)"; then
    fail "sysctl command is not available"
    return
  fi

  ok "sysctl command is available: ${sysctl_bin}"

  check_sysctl_value() {
    local key="$1"
    local expected="$2"
    local actual

    actual="$(${SUDO} "${sysctl_bin}" -n "${key}" 2>/dev/null || true)"

    if [[ "${actual}" == "${expected}" ]]; then
      ok "sysctl ${key} = ${expected}"
    else
      fail "sysctl ${key} expected ${expected}, got '${actual:-missing}'"
    fi
  }

  check_sysctl_value "net.ipv4.conf.all.accept_redirects" "0"
  check_sysctl_value "net.ipv4.conf.default.accept_redirects" "0"
  check_sysctl_value "net.ipv4.conf.all.send_redirects" "0"
  check_sysctl_value "net.ipv4.conf.default.send_redirects" "0"
  check_sysctl_value "net.ipv4.conf.all.accept_source_route" "0"
  check_sysctl_value "net.ipv4.conf.default.accept_source_route" "0"
  check_sysctl_value "net.ipv4.icmp_echo_ignore_broadcasts" "1"
  check_sysctl_value "net.ipv4.tcp_syncookies" "1"

  if [[ -f /etc/sysctl.d/99-workstation-security.conf ]]; then
    ok "Sysctl hardening file exists"
  else
    fail "Sysctl hardening file is missing"
  fi
}

check_docker() {
  log_section "Docker checks"

  if ! command_exists docker; then
    fail "docker is not installed"
    return
  fi

  ok "Docker version: $(docker --version)"

  if systemctl is-enabled docker >/dev/null 2>&1; then
    ok "docker service is enabled"
  else
    warn "docker service is not enabled"
  fi

  if systemctl is-active docker >/dev/null 2>&1; then
    ok "docker service is active"
  else
    fail "docker service is not active"
  fi

  if [[ -n "${DEV_USER:-}" ]]; then
    if id "${DEV_USER}" 2>/dev/null | grep -q '\bdocker\b'; then
      ok "Developer user '${DEV_USER}' is in docker group"
    else
      if [[ "${OS_ID}" == "ubuntu" || "${OS_ID}" == "debian" ]]; then
        fail "Developer user '${DEV_USER}' is not in docker group"
      else
        warn "Developer user '${DEV_USER}' is not in docker group; this is expected on Astra"
      fi
    fi
  fi

  if docker compose version >/dev/null 2>&1; then
    ok "Docker Compose plugin is available: $(docker compose version)"
  else
    if [[ "${OS_ID}" == "ubuntu" || "${OS_ID}" == "debian" ]]; then
      fail "Docker Compose plugin is not available on Ubuntu/Debian"
    else
      warn "Docker Compose plugin is not available; this may be expected on Astra"
    fi
  fi
}

check_python_dev_tools() {
  log_section "Python developer environment checks"

  if [[ "${OS_ID}" == "ubuntu" || "${OS_ID}" == "debian" ]]; then
    if command_exists python3; then
      ok "Python: $(python3 --version)"
    else
      fail "python3 is not installed"
    fi
  elif [[ "${OS_ID}" == "astra" || "${OS_ID}" == "astra_se" || "${OS_ID}" == "orel" ]]; then
    if [[ -x /usr/local/bin/python3.9 ]]; then
      ok "Astra bootstrap Python: $(/usr/local/bin/python3.9 --version)"
    else
      fail "Astra bootstrap Python /usr/local/bin/python3.9 is missing"
    fi
  else
    warn "Unsupported OS for Python baseline check: ${OS_ID}"
  fi

  if [[ -z "${DEV_USER:-}" ]]; then
    fail "Developer user is unknown; cannot check user dev tools"
    return
  fi

  local dev_home
  dev_home="$(getent passwd "${DEV_USER}" | cut -d: -f6)"

  if [[ -z "${dev_home}" ]]; then
    fail "Could not determine home directory for '${DEV_USER}'"
    return
  fi

  run_as_user() {
    local target_user="$1"
    shift

    if command_exists sudo; then
      sudo -u "${target_user}" "$@"
    elif [[ "$(id -u)" -eq 0 ]] && command_exists runuser; then
      runuser -u "${target_user}" -- "$@"
    else
      return 1
    fi
  }

  check_user_tool() {
    local tool="$1"
    local binary_name="${2:-$1}"
    local tool_path="${dev_home}/.local/bin/${binary_name}"
    local version_output

    if run_as_user "${DEV_USER}" test -x "${tool_path}"; then
      version_output="$(run_as_user "${DEV_USER}" "${tool_path}" --version 2>/dev/null | head -n 1 || true)"

      if [[ -n "${version_output}" ]]; then
        ok "${tool} is installed for ${DEV_USER}: ${version_output}"
      else
        ok "${tool} is installed for ${DEV_USER}: ${tool_path}"
      fi
    else
      fail "${tool} is not installed for ${DEV_USER}"
    fi
  }

  check_user_tool "uv"
  check_user_tool "ruff"
  check_user_tool "black"
  check_user_tool "isort"
  check_user_tool "mypy"
  check_user_tool "pytest"
  check_user_tool "pre-commit"
  check_user_tool "poetry"

  # httpie exposes the main executable as "http"
  check_user_tool "httpie" "http"

  if run_as_user "${DEV_USER}" git config --global user.name >/dev/null 2>&1; then
    ok "Git user.name is configured for ${DEV_USER}: $(run_as_user "${DEV_USER}" git config --global user.name)"
  else
    warn "Git user.name is not configured for ${DEV_USER}"
  fi

  if run_as_user "${DEV_USER}" git config --global user.email >/dev/null 2>&1; then
    ok "Git user.email is configured for ${DEV_USER}: $(run_as_user "${DEV_USER}" git config --global user.email)"
  else
    warn "Git user.email is not configured for ${DEV_USER}"
  fi
}

print_summary() {
  log_section "Verification summary"

  echo "[OK]   ${STATUS_OK}"
  echo "[WARN] ${STATUS_WARN}"
  echo "[FAIL] ${STATUS_FAIL}"

  echo

  if [[ "${STATUS_FAIL}" -eq 0 ]]; then
    echo "Result: workstation verification completed successfully."
    exit 0
  else
    echo "Result: workstation verification failed."
    exit 1
  fi
}

main() {
  get_os_info
  require_root_or_sudo

  check_basic_system
  check_users
  check_ssh_security
  check_fail2ban
  check_firewall
  check_sysctl
  check_docker
  check_python_dev_tools
  print_summary
}

main "$@"