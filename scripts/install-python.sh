#!/usr/bin/env bash
set -Eeuo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.9.19}"
PYTHON_MAJOR_MINOR="${PYTHON_VERSION%.*}"
PREFIX="${PREFIX:-/opt/python/${PYTHON_MAJOR_MINOR}}"
SRC_DIR="${SRC_DIR:-/usr/local/src}"
TARBALL="Python-${PYTHON_VERSION}.tgz"
SRC_FOLDER="Python-${PYTHON_VERSION}"
URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/${TARBALL}"
LOG_FILE="${LOG_FILE:-/var/log/install-python-${PYTHON_MAJOR_MINOR}.log}"
EXPECTED_SHA256="${EXPECTED_SHA256:-}"

usage() {
  cat <<EOF
Usage: sudo bash install-python.sh [options]

Options:
  --version <ver>       Python version to install (default: ${PYTHON_VERSION})
  --prefix <path>       Installation prefix (default: ${PREFIX})
  --src-dir <path>      Source directory (default: ${SRC_DIR})
  --sha256 <hash>       Expected SHA256 checksum for tarball
  --help                Show this help

Examples:
  sudo bash install-python.sh --version 3.9.19
  sudo bash install-python.sh --version 3.9.19 --sha256 <hash>
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        PYTHON_VERSION="$2"
        PYTHON_MAJOR_MINOR="${PYTHON_VERSION%.*}"
        PREFIX="/opt/python/${PYTHON_MAJOR_MINOR}"
        TARBALL="Python-${PYTHON_VERSION}.tgz"
        SRC_FOLDER="Python-${PYTHON_VERSION}"
        URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/${TARBALL}"
        shift 2
        ;;
      --prefix)
        PREFIX="$2"
        shift 2
        ;;
      --src-dir)
        SRC_DIR="$2"
        shift 2
        ;;
      --sha256)
        EXPECTED_SHA256="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

log() {
  printf '\n[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
}

die() {
  log "ERROR: $*"
  exit 1
}

on_error() {
  local line="$1"
  log "Ошибка на строке ${line}. Установка прервана."
}
trap 'on_error $LINENO' ERR

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Запусти скрипт от root или через sudo."
  fi
}

prepare_logging() {
  mkdir -p "$(dirname "${LOG_FILE}")"
  touch "${LOG_FILE}"
  chmod 600 "${LOG_FILE}"
}

check_existing_install() {
  local bin_path="${PREFIX}/bin/python${PYTHON_MAJOR_MINOR}"

  if [[ -x "${bin_path}" ]]; then
    local installed_version
    installed_version="$("${bin_path}" --version 2>&1 | awk '{print $2}')"

    if [[ "${installed_version}" == "${PYTHON_VERSION}" ]]; then
      log "Python ${PYTHON_VERSION} уже установлен в ${PREFIX}. Повторная установка не требуется."
      exit 0
    else
      log "В ${PREFIX} уже найден Python ${installed_version}, будет выполнена переустановка на ${PYTHON_VERSION}."
    fi
  fi
}

install_build_deps() {
  log "Установка зависимостей для сборки Python"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    wget \
    curl \
    ca-certificates \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    uuid-dev \
    libgdbm-dev \
    libdb5.3-dev \
    libexpat1-dev \
    openssl
}

download_source() {
  log "Скачивание исходников Python ${PYTHON_VERSION}"
  mkdir -p "${SRC_DIR}"
  cd "${SRC_DIR}"

  if [[ ! -f "${TARBALL}" ]]; then
    wget -O "${TARBALL}" "${URL}"
  else
    log "Архив уже существует: ${SRC_DIR}/${TARBALL}"
  fi
}

verify_checksum() {
  if [[ -n "${EXPECTED_SHA256}" ]]; then
    log "Проверка SHA256 контрольной суммы"
    local actual_sha256
    actual_sha256="$(sha256sum "${SRC_DIR}/${TARBALL}" | awk '{print $1}')"

    if [[ "${actual_sha256}" != "${EXPECTED_SHA256}" ]]; then
      die "Контрольная сумма не совпадает. Ожидалось: ${EXPECTED_SHA256}, получено: ${actual_sha256}"
    fi

    log "Контрольная сумма подтверждена"
  else
    log "SHA256 не задана, проверка контрольной суммы пропущена"
  fi
}

extract_source() {
  log "Распаковка исходников"
  cd "${SRC_DIR}"

  if [[ -d "${SRC_FOLDER}" ]]; then
    log "Каталог исходников уже существует, удаляю старую распаковку"
    rm -rf "${SRC_FOLDER}"
  fi

  tar -xzf "${TARBALL}"
}

build_python() {
  log "Сборка Python ${PYTHON_VERSION} в ${PREFIX}"
  cd "${SRC_DIR}/${SRC_FOLDER}"

  ./configure \
    --prefix="${PREFIX}" \
    --enable-optimizations \
    --with-ensurepip=install

  make -j"$(nproc)"
  make altinstall
}

post_install() {
  log "Постустановочная настройка"

  ln -sf "${PREFIX}/bin/python${PYTHON_MAJOR_MINOR}" "/usr/local/bin/python${PYTHON_MAJOR_MINOR}"
  ln -sf "${PREFIX}/bin/pip${PYTHON_MAJOR_MINOR}" "/usr/local/bin/pip${PYTHON_MAJOR_MINOR}"
}

validate_install() {
  log "Проверка установленного Python"

  [[ -x "${PREFIX}/bin/python${PYTHON_MAJOR_MINOR}" ]] || die "Python бинарник не найден в ${PREFIX}/bin"
  [[ -x "/usr/local/bin/python${PYTHON_MAJOR_MINOR}" ]] || die "Симлинк /usr/local/bin/python${PYTHON_MAJOR_MINOR} не создан"

  local py_ver
  py_ver="$("${PREFIX}/bin/python${PYTHON_MAJOR_MINOR}" --version 2>&1 | awk '{print $2}')"

  if [[ "${py_ver}" != "${PYTHON_VERSION}" ]]; then
    die "Ожидалась версия ${PYTHON_VERSION}, но получена ${py_ver}"
  fi

  "${PREFIX}/bin/python${PYTHON_MAJOR_MINOR}" --version | tee -a "${LOG_FILE}"
  "${PREFIX}/bin/pip${PYTHON_MAJOR_MINOR}" --version | tee -a "${LOG_FILE}"
}

show_summary() {
  log "Готово"
  log "Python установлен в: ${PREFIX}"
  log "Интерпретатор для Ansible: /usr/local/bin/python${PYTHON_MAJOR_MINOR}"
  log "Лог установки: ${LOG_FILE}"
  echo "ansible_python_interpreter=/usr/local/bin/python${PYTHON_MAJOR_MINOR}"
}

main() {
  parse_args "$@"
  require_root
  prepare_logging
  check_existing_install
  install_build_deps
  download_source
  verify_checksum
  extract_source
  build_python
  post_install
  validate_install
  show_summary
}

main "$@"
