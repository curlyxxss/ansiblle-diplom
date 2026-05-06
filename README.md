# 🛡️ Automated Secure Developer Workstation Setup

## 📌 Описание проекта

Проект представляет собой систему автоматизированной подготовки рабочих станций разработчиков с использованием Ansible.

Основная цель проекта — обеспечить воспроизводимую, управляемую и безопасную настройку рабочих машин для разработки. Проект решает задачу централизованной конфигурации Linux-станций, включая базовую настройку ОС, управление пользователями, политики безопасности, Docker и Python-oriented dev-среду.

Проект ориентирован на сценарий корпоративной разработки, где важно:

- минимизировать ручную настройку;
- обеспечить единый baseline рабочих станций;
- разделить административный доступ и пользовательскую работу;
- повысить безопасность SSH-доступа;
- подготовить систему к разработке сразу после применения playbook'ов.

---

## 🧩 Поддерживаемые платформы

Текущая версия проекта проверялась на:

- Ubuntu 24.04
- Astra Linux Orel

Для Astra Linux реализована отдельная логика, так как система имеет особенности, связанные с Python, пакетным менеджером и доступными версиями программного обеспечения.

---

## 🏗️ Архитектура проекта

Проект построен на основе Ansible-ролей.

| Роль | Назначение |
|---|---|
| `base` | Базовая настройка ОС: пакеты, timezone, locale, hostname |
| `users` | Управление пользователями, SSH-ключами и sudo-доступом |
| `security` | SSH hardening, fail2ban, firewall |
| `docker` | Установка Docker Engine и настройка доступа к Docker |
| `dev` | Python-oriented среда разработки |

Роли разделены по зонам ответственности. Это позволяет развивать проект поэтапно и не смешивать базовую настройку, безопасность, контейнеризацию и пользовательские dev-инструменты.

---

## 👥 Итоговая модель пользователей

В проекте используется разделение административного пользователя Ansible и пользователя-разработчика.

### 🔧 `ansible`

Служебный пользователь автоматизации.

Назначение:

- подключение Ansible к целевым машинам;
- выполнение playbook'ов;
- использование `become`;
- административная настройка системы.

Особенности:

- SSH-доступ по ключу;
- sudo-доступ;
- `NOPASSWD`;
- не используется для ежедневной работы разработчика.

### 👨‍💻 `developer`

Пользователь-разработчик.

Назначение:

- повседневная работа;
- запуск Docker;
- использование Python dev-инструментов;
- Git;
- разработка.

Особенности:

- SSH-доступ по ключу;
- без административного sudo-доступа по умолчанию;
- Docker-доступ выдаётся отдельно через группу `docker`;
- dev-инструменты устанавливаются в пользовательское окружение.

---

## 🚀 Основной pipeline настройки машины

Инициализация новой машины разделена на два этапа:

1. **Bootstrap provisioning** — первичная подготовка машины и создание пользователя `ansible`.
2. **Configuration management** — дальнейшая настройка через Ansible-роли.

Общая схема:

```text
Установка ОС
    ↓
Первичный доступ через setup/root/console
    ↓
Bootstrap пользователя ansible
    ↓
Добавление машины в inventory
    ↓
Запуск Ansible playbook'ов
    ↓
Готовая рабочая станция разработчика
```

Подробно процесс описан в документе:

```text
docs/machine-initialization-pipeline.md
```

---

## 🔑 Bootstrap пользователя Ansible

Перед полноценным запуском Ansible на чистой машине требуется создать служебного пользователя `ansible`.

Для этого используется скрипт:

```text
scripts/bootstrap-ansible-user.sh
```

Скрипт выполняет:

- создание пользователя `ansible`;
- настройку SSH-ключа;
- настройку sudo-доступа;
- создание `/etc/sudoers.d/ansible`;
- блокировку парольного входа;
- проверку sudoers-файла через `visudo`.

Пример запуска через файл публичного ключа:

```bash
sudo PUBLIC_KEY_FILE=/tmp/ansible.pub bash scripts/bootstrap-ansible-user.sh
```

Пример запуска через переменную:

```bash
sudo ANSIBLE_PUBLIC_KEY="ssh-ed25519 AAAA... ansible-key" bash scripts/bootstrap-ansible-user.sh
```

Подробная документация:

```text
docs/bootstrap-ansible-user.md
```

---

## 🐍 Особенности Astra Linux

Astra Linux Orel требует отдельного bootstrap-этапа для Python.

Причина: системный Python Astra не подходит для полноценной работы современных Ansible-модулей и dev-инструментов.

Для Astra используется скрипт:

```text
scripts/install-python.sh
```

Он устанавливает Python 3.9 в:

```text
/opt/python/3.9
```

Для Ansible используется стабильная точка входа:

```text
/usr/local/bin/python3.9
```

В inventory для Astra необходимо указать:

```ini
ansible_python_interpreter=/usr/local/bin/python3.9
```

Подробная инструкция:

```text
docs/bootstrap-astra.md
```

---

## ✅ Что реализовано

### 🔹 Роль `base`

Роль выполняет базовую настройку операционной системы.

Реализовано:

- обновление пакетного кэша;
- установка базовых пакетов;
- настройка timezone;
- настройка locale;
- настройка hostname;
- валидация hostname;
- управление записью в `/etc/hosts`;
- отдельная логика для Ubuntu и Astra Linux;
- использование `raw` на Astra там, где стандартные модули Ansible работают ограниченно.

Hostname задаётся через `host_vars`.

Пример:

```yaml
base_hostname: dev-ubuntu-01
```

---

### 🔹 Роль `users`

Роль управляет пользователями и доступом.

Реализовано:

- создание пользователей;
- настройка shell;
- создание home directory;
- настройка `.ssh`;
- установка SSH-ключей;
- настройка sudo через `/etc/sudoers.d`;
- удаление sudoers-файла для пользователей без sudo;
- поддержка пользователей со `state: absent`;
- разделение служебного пользователя `ansible` и пользователя-разработчика.

---

### 🔹 Роль `security`

Роль реализует базовый security baseline рабочей станции.

#### 🔐 SSH hardening

Реализовано:

- отключение root login;
- отключение password authentication;
- включение public key authentication;
- ограничение входа через `AllowUsers`;
- настройка `MaxAuthTries`;
- настройка `LoginGraceTime`;
- настройка `ClientAliveInterval`;
- настройка `ClientAliveCountMax`;
- проверка конфигурации через `sshd -t`;
- безопасный reload/restart SSH через handlers.

Для playbook'а `security.yml` используется:

```yaml
force_handlers: true
```

Это нужно, чтобы SSH handler выполнялся даже при ошибке на другом хосте.

#### 🧱 Fail2ban

Реализовано:

- установка fail2ban;
- настройка jail для `sshd`;
- запуск и включение сервиса;
- защита от brute-force атак.

#### 🔥 Firewall

Реализовано:

- установка `ufw`;
- политика `deny incoming`;
- политика `allow outgoing`;
- разрешение только явно указанных портов;
- включение firewall.

По умолчанию открыт SSH-порт.

---

### 🔹 Роль `docker`

Роль устанавливает Docker Engine и настраивает доступ к Docker.

#### 🐧 Ubuntu

Для Ubuntu используется официальный Docker repository.

Реализовано:

- удаление конфликтующих Docker-пакетов;
- добавление GPG-ключа Docker;
- добавление Docker apt repository;
- установка Docker Engine;
- установка Docker CLI;
- установка containerd;
- установка Buildx plugin;
- установка Compose plugin;
- запуск и включение сервиса Docker;
- добавление пользователя-разработчика в группу `docker`.

#### 🛡️ Astra Linux

Для Astra Linux была реализована экспериментальная установка через официальный Debian-based Docker repository.

Результат:

- Docker Engine устанавливается;
- сервис запускается;
- пользователь может быть добавлен в группу `docker`.

Ограничение:

- доступная версия Docker на Astra Linux Orel устарела;
- современные Docker plugins могут быть недоступны;
- Docker на Astra считается ограниченно поддерживаемым.

Для production-like Docker workflow рекомендуется использовать Ubuntu.

---

### 🔹 Роль `dev`

Роль настраивает Python-oriented среду разработки.

Реализовано:

- установка Python dev-пакетов на Ubuntu;
- использование bootstrap Python 3.9 на Astra;
- установка build dependencies;
- установка дополнительных CLI-инструментов;
- настройка `pipx`;
- установка Python CLI-инструментов через `pipx`;
- настройка Git для пользователя-разработчика.

По умолчанию через `pipx` устанавливаются:

- `uv`;
- `ruff`;
- `black`;
- `isort`;
- `mypy`;
- `pytest`;
- `pre-commit`;
- `poetry`;
- `httpie`.

Особенность:

- Ubuntu использует системный Python 3.12;
- Astra использует Python 3.9 из bootstrap;
- версии Python CLI-инструментов могут отличаться из-за разных версий Python.

Роль проверена повторным запуском с результатом:

```text
changed=0
failed=0
unreachable=0
```

---

## 📁 Структура проекта

```text
.
├── ansible.cfg
├── docs
│   ├── bootstrap-ansible-user.md
│   ├── bootstrap-astra.md
│   └── machine-initialization-pipeline.md
├── files
│   └── ssh_keys
│       ├── ansible.pub.example
│       └── developer.pub.example
├── .gitignore
├── inventories
│   ├── group_vars
│   │   ├── workstations.yml
│   │   └── workstations.yml.example
│   ├── host_vars
│   │   ├── astra.yml
│   │   ├── astra.yml.example
│   │   ├── ubuntu.yml
│   │   └── ubuntu.yml.example
│   ├── inventory.ini
│   └── inventory.ini.example
├── playbooks
│   ├── base.yml
│   ├── dev.yml
│   ├── docker.yml
│   ├── security.yml
│   └── users.yml
├── README.md
├── roles
│   ├── base
│   ├── dev
│   ├── docker
│   ├── security
│   └── users
└── scripts
    ├── bootstrap-ansible-user.sh
    └── install-python.sh
```

Важно:

- реальные inventory-файлы используются локально;
- `.example` файлы хранятся в Git;
- реальные SSH-ключи не должны попадать в репозиторий;
- реальные `inventories/*.yml` и `inventory.ini` игнорируются через `.gitignore`.

---

## ⚙️ Подготовка локальных файлов из examples

После клонирования репозитория нужно создать локальные конфигурационные файлы из шаблонов.

```bash
cp inventories/inventory.ini.example inventories/inventory.ini
cp inventories/group_vars/workstations.yml.example inventories/group_vars/workstations.yml
cp inventories/host_vars/astra.yml.example inventories/host_vars/astra.yml
cp inventories/host_vars/ubuntu.yml.example inventories/host_vars/ubuntu.yml
```

Далее нужно положить реальные публичные ключи:

```bash
cp ~/.ssh/ansible.pub files/ssh_keys/ansible.pub
cp ~/.ssh/developer.pub files/ssh_keys/developer.pub
```

Эти файлы игнорируются Git.

---

## 🧾 Пример inventory

Пример для обычной сети:

```ini
[astra_hosts]
astra-01 ansible_host=<astra_ip_or_hostname> ansible_port=22 ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9

[ubuntu_hosts]
ubuntu-01 ansible_host=<ubuntu_ip_or_hostname> ansible_port=22 ansible_user=ansible

[workstations:children]
astra_hosts
ubuntu_hosts
```

Пример для лабораторного стенда с пробросом портов:

```ini
[astra_hosts]
astra ansible_host=<lab_host_ip> ansible_port=2222 ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9

[ubuntu_hosts]
ubuntu ansible_host=<lab_host_ip> ansible_port=2223 ansible_user=ansible

[workstations:children]
astra_hosts
ubuntu_hosts
```

---

## 🧾 Пример group_vars

Пример `inventories/group_vars/workstations.yml`:

```yaml
---
users:
  - name: ansible
    state: present
    shell: /bin/bash
    groups:
      - sudo
    ssh_keys:
      - "files/ssh_keys/ansible.pub"
    sudo: true
    sudo_nopasswd: true
    password_lock: true

  - name: developer
    state: present
    shell: /bin/bash
    groups: []
    ssh_keys:
      - "files/ssh_keys/developer.pub"
    sudo: false
    sudo_nopasswd: false
    password_lock: true

security_ssh_allow_users:
  - ansible
  - developer

docker_users:
  - developer

dev_users:
  - developer

dev_git_config_enabled: true
dev_git_user_name: "Developer User"
dev_git_user_email: "developer@example.com"
```

---

## ▶️ Порядок запуска playbook'ов

Рекомендуемый порядок:

```bash
ansible-playbook playbooks/base.yml
ansible-playbook playbooks/users.yml
ansible-playbook playbooks/security.yml
ansible-playbook playbooks/docker.yml
ansible-playbook playbooks/dev.yml
```

Назначение этапов:

| Playbook | Назначение |
|---|---|
| `base.yml` | Базовая настройка ОС |
| `users.yml` | Пользователи, SSH-ключи, sudo |
| `security.yml` | SSH hardening, fail2ban, firewall |
| `docker.yml` | Docker Engine и Docker-доступ |
| `dev.yml` | Python-oriented dev-среда |

---

## 🧪 Проверка после запуска

### Проверка доступности

```bash
ansible all -m ping
```

### Проверка пользователя Ansible

```bash
ansible all -m command -a "whoami"
```

Ожидаемый результат:

```text
ansible
```

Проверка `become`:

```bash
ansible all -m command -a "whoami" -b
```

Ожидаемый результат:

```text
root
```

---

### Проверка hostname

```bash
ansible all -m command -a "hostname"
```

---

### Проверка security

На целевой машине:

```bash
sudo sshd -T | grep -i allowusers
sudo fail2ban-client status
sudo ufw status verbose
```

Ожидаемо:

- SSH разрешает только заданных пользователей;
- fail2ban активен;
- firewall активен;
- входящие соединения запрещены по умолчанию;
- SSH-порт разрешён.

---

### Проверка Docker

```bash
docker --version
docker ps
```

Для Ubuntu также ожидается:

```bash
docker compose version
```

---

### Проверка dev-среды

Для Ubuntu:

```bash
python3 --version
pipx list
uv --version
ruff --version
pytest --version
git config --global --list
```

Для Astra:

```bash
/usr/local/bin/python3.9 --version
/usr/local/bin/python3.9 -m pipx list
~/.local/bin/uv --version
~/.local/bin/ruff --version
git config --global --list
```

---

## 🔐 Безопасность

Проект реализует несколько уровней защиты:

- SSH-доступ только по ключам;
- отключение password authentication;
- запрет root login;
- ограничение SSH-доступа через `AllowUsers`;
- fail2ban для защиты от brute-force;
- firewall с политикой `deny incoming`;
- Docker-доступ только явно указанным пользователям;
- разделение пользователя Ansible и пользователя-разработчика;
- пользовательские Python CLI-инструменты устанавливаются через `pipx`, без изменения системного Python;
- реальные ключи и inventory-файлы не хранятся в Git.

---

## ⚠️ Ограничения текущей версии

На текущем этапе проект не реализует:

- rootless Docker;
- корпоративный Docker registry;
- централизованный сбор логов;
- auditd-политику;
- SIEM-интеграцию;
- установку VS Code или других GUI-инструментов;
- поддержку Red Hat-like систем;
- полноценную production-поддержку Docker на Astra Linux;
- строгую фиксацию версий всех Python CLI-инструментов.

---

## 📈 Планы развития

Возможные направления развития:

- `users v2`: расширенная модель пользователей;
- `security v3`: дополнительные SSH-политики, auditd, расширенные firewall-правила;
- безопасное хранение и ротация ключей;
- интеграция с Ansible Vault;
- поддержка Debian и Linux Mint;
- отдельная роль для VS Code / GUI-инструментов;
- rootless Docker;
- version pinning для Python CLI-инструментов;
- cloud-init/autoinstall для полностью автоматизированного bootstrap.

---

## 📚 Документация

Дополнительные документы:

```text
docs/bootstrap-ansible-user.md
```

Описание bootstrap-скрипта для создания служебного пользователя Ansible.

```text
docs/bootstrap-astra.md
```

Описание подготовки Astra Linux для работы с Ansible.

```text
docs/machine-initialization-pipeline.md
```

Описание полного pipeline инициализации новой машины.

---

## 🎯 Текущий результат

Проект реализует полный цикл подготовки рабочей станции разработчика:

1. первичная подготовка машины;
2. создание служебного пользователя Ansible;
3. базовая настройка ОС;
4. управление пользователями;
5. применение политики безопасности;
6. установка Docker;
7. настройка Python-oriented dev-среды.

После применения всех playbook'ов машина становится управляемой, защищённой и готовой к разработке.

---

## 📝 Примечание

Проект разрабатывается как практическая часть дипломной работы и демонстрирует подход к автоматизации настройки защищённых рабочих станций разработчиков.

Основной акцент сделан на:

- воспроизводимости;
- безопасности;
- разделении ответственности;
- поддержке нескольких Linux-дистрибутивов;
- реалистичном процессе подключения новых машин к управлению.