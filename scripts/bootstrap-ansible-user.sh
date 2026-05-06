#!/usr/bin/env bash

set -euo pipefail

ANSIBLE_USER="${ANSIBLE_USER:-ansible}"
ANSIBLE_SHELL="${ANSIBLE_SHELL:-/bin/bash}"
PUBLIC_KEY_FILE="${PUBLIC_KEY_FILE:-}"
ANSIBLE_PUBLIC_KEY="${ANSIBLE_PUBLIC_KEY:-}"

log() {
  echo "[bootstrap] $*"
}

fail() {
  echo "[bootstrap][ERROR] $*" >&2
  exit 1
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    fail "This script must be run as root. Use sudo."
  fi
}

detect_sudo_group() {
  if getent group sudo >/dev/null 2>&1; then
    echo "sudo"
  elif getent group wheel >/dev/null 2>&1; then
    echo "wheel"
  else
    fail "Neither 'sudo' nor 'wheel' group exists."
  fi
}

is_valid_public_key() {
  grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+) '
}

validate_public_key_input() {
  if [[ -n "${PUBLIC_KEY_FILE}" ]]; then
    if [[ ! -f "${PUBLIC_KEY_FILE}" ]]; then
      fail "Public key file not found: ${PUBLIC_KEY_FILE}"
    fi

    if ! is_valid_public_key < "${PUBLIC_KEY_FILE}"; then
      fail "File does not look like a valid SSH public key: ${PUBLIC_KEY_FILE}"
    fi

    return 0
  fi

  if [[ -n "${ANSIBLE_PUBLIC_KEY}" ]]; then
    if ! printf '%s\n' "${ANSIBLE_PUBLIC_KEY}" | is_valid_public_key; then
      fail "ANSIBLE_PUBLIC_KEY does not look like a valid SSH public key"
    fi

    return 0
  fi

  fail "No public key provided. Use PUBLIC_KEY_FILE=/tmp/ansible.pub or ANSIBLE_PUBLIC_KEY='ssh-ed25519 AAAA...'"
}

create_user() {
  if id "${ANSIBLE_USER}" >/dev/null 2>&1; then
    log "User '${ANSIBLE_USER}' already exists"
  else
    log "Creating user '${ANSIBLE_USER}'"
    useradd -m -s "${ANSIBLE_SHELL}" "${ANSIBLE_USER}"
  fi
}

configure_ssh_key() {
  local home_dir
  home_dir="$(getent passwd "${ANSIBLE_USER}" | cut -d: -f6)"

  if [[ -z "${home_dir}" ]]; then
    fail "Could not determine home directory for user '${ANSIBLE_USER}'"
  fi

  log "Configuring SSH key for '${ANSIBLE_USER}'"

  install -d -m 700 -o "${ANSIBLE_USER}" -g "${ANSIBLE_USER}" "${home_dir}/.ssh"

  if [[ -n "${PUBLIC_KEY_FILE}" ]]; then
    install -m 600 -o "${ANSIBLE_USER}" -g "${ANSIBLE_USER}" \
      "${PUBLIC_KEY_FILE}" "${home_dir}/.ssh/authorized_keys"
  else
    printf '%s\n' "${ANSIBLE_PUBLIC_KEY}" > "${home_dir}/.ssh/authorized_keys"
    chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "${home_dir}/.ssh/authorized_keys"
    chmod 600 "${home_dir}/.ssh/authorized_keys"
  fi

  chmod 755 "${home_dir}"
  chmod 700 "${home_dir}/.ssh"
  chmod 600 "${home_dir}/.ssh/authorized_keys"
  chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "${home_dir}/.ssh"
}

configure_sudo() {
  local sudo_group
  sudo_group="$(detect_sudo_group)"

  log "Adding '${ANSIBLE_USER}' to '${sudo_group}' group"
  usermod -aG "${sudo_group}" "${ANSIBLE_USER}"

  log "Configuring passwordless sudo for '${ANSIBLE_USER}'"

  cat > "/etc/sudoers.d/${ANSIBLE_USER}" <<EOF
${ANSIBLE_USER} ALL=(ALL) NOPASSWD:ALL
EOF

  chmod 0440 "/etc/sudoers.d/${ANSIBLE_USER}"

  if ! visudo -cf "/etc/sudoers.d/${ANSIBLE_USER}" >/dev/null; then
    rm -f "/etc/sudoers.d/${ANSIBLE_USER}"
    fail "Invalid sudoers file generated"
  fi
}

lock_password() {
  log "Locking password for '${ANSIBLE_USER}'"
  passwd -l "${ANSIBLE_USER}" >/dev/null 2>&1 || true
}

main() {
  require_root
  validate_public_key_input
  create_user
  configure_ssh_key
  configure_sudo
  lock_password

  log "Bootstrap completed successfully"
  log "User: ${ANSIBLE_USER}"

  if [[ -n "${PUBLIC_KEY_FILE}" ]]; then
    log "SSH key installed from: ${PUBLIC_KEY_FILE}"
  else
    log "SSH key installed from: ANSIBLE_PUBLIC_KEY"
  fi

  log "Test from control host:"
  log "  ssh ${ANSIBLE_USER}@<host>"
  log "  sudo whoami"
}

main "$@"