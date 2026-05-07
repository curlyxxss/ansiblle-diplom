# 🛡️ Automated Secure Developer Workstation Setup

## 📌 Описание проекта

Проект представляет собой систему автоматизированной подготовки защищённых рабочих станций разработчиков с использованием Ansible.

Основная цель проекта — обеспечить воспроизводимую, управляемую и безопасную настройку Linux-станций для разработки. Проект автоматизирует полный цикл подготовки машины: от первичного bootstrap-доступа до настройки пользователей, безопасности, Docker и Python-oriented dev-среды.

Проект ориентирован на сценарий корпоративной разработки, где важно:

- минимизировать ручную настройку рабочих станций;
- обеспечить единый baseline конфигурации;
- разделить административный доступ и пользовательскую работу;
- повысить безопасность SSH-доступа;
- подготовить систему к разработке сразу после применения playbook'ов;
- сохранить возможность расширения под новые дистрибутивы и роли.

---

## 🧩 Поддерживаемые платформы

Проект проверен на новых чистых виртуальных машинах:

- Ubuntu 24.04
- Astra Linux Orel

Для Astra Linux реализована отдельная логика, так как система имеет особенности, связанные с Python, пакетным менеджером и доступными версиями программного обеспечения.

---

## 🏗️ Архитектура проекта

Проект построен на основе Ansible-ролей.

| Роль | Назначение |
|---|---|
| `base` | Базовая настройка ОС: пакеты, timezone, locale, hostname |
| `users` | Управление пользователями, SSH-ключами, sudo и блокировкой паролей |
| `security` | SSH hardening, fail2ban, firewall, sysctl hardening |
| `docker` | Установка Docker Engine и настройка доступа к Docker |
| `dev` | Python-oriented среда разработки |

Роли разделены по зонам ответственности. Это позволяет развивать проект поэтапно и не смешивать базовую настройку, безопасность, контейнеризацию и пользовательские dev-инструменты.

Рекомендуемый порядок применения:

```text
base -> users -> security -> docker -> dev
```

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
- парольный вход заблокирован;
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
- dev-инструменты устанавливаются в пользовательское окружение;
- парольный вход может быть заблокирован, если используется SSH-only модель.

---

## 🚀 Основной pipeline настройки новой машины

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
Bootstrap Python для Astra Linux
    ↓
Запуск Ansible playbook'ов
    ↓
Проверка результата
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

Важно: имя файла в `host_vars` должно совпадать с именем хоста в inventory.

Например, если в inventory указан хост:

```ini
ubuntu-02
```

то файл переменных должен называться:

```text
inventories/host_vars/ubuntu-02.yml
```

---

### 🔹 Роль `users`

Роль управляет пользователями и доступом.

Реализовано:

- создание пользователей;
- настройка shell;
- настройка comment/GECOS;
- создание home directory;
- настройка `.ssh`;
- установка SSH-ключей;
- настройка sudo через `/etc/sudoers.d`;
- удаление sudoers-файла для пользователей без sudo;
- блокировка парольного входа через `password_lock`;
- поддержка пользователей со `state: absent`;
- управление удалением home directory через `remove_home`;
- разделение служебного пользователя `ansible` и пользователя-разработчика.

Роль не удаляет пользователей, которые не описаны в переменной `users`. Удаление выполняется только явно через:

```yaml
state: absent
```

Для SSH-only пользователей рекомендуется:

```yaml
password_lock: true
```

---

### 🔹 Роль `security`

Роль реализует security baseline рабочей станции.

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
- запрет пустых паролей;
- отключение X11 forwarding;
- управляемое отключение TCP forwarding;
- ограничение числа SSH-сессий;
- ограничение числа неаутентифицированных подключений;
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

#### 🌐 Sysctl hardening

Реализованы базовые сетевые sysctl-настройки:

- запрет ICMP redirects;
- запрет source routing;
- отключение отправки redirects;
- защита от broadcast ICMP;
- включение TCP SYN cookies.

Настройки записываются в:

```text
/etc/sysctl.d/99-workstation-security.conf
```

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

Для Astra Linux реализована экспериментальная установка через официальный Debian-based Docker repository.

Результат:

- Docker Engine устанавливается;
- сервис запускается;
- пользователь может быть добавлен в группу `docker`.

Ограничение:

- доступная версия Docker на Astra Linux Orel устарела;
- современные Docker plugins могут быть недоступны;
- Docker на Astra считается рабочим, но ограниченно поддерживаемым вариантом.

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

- Ubuntu использует системный Python;
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
│   │   ├── ubuntu-02.yml
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
│   │   ├── defaults
│   │   │   └── main.yml
│   │   ├── handlers
│   │   │   └── main.yml
│   │   ├── README.md
│   │   └── tasks
│   │       ├── astra.yml
│   │       ├── common.yml
│   │       ├── main.yml
│   │       └── ubuntu.yml
│   ├── dev
│   │   ├── defaults
│   │   │   └── main.yml
│   │   ├── README.md
│   │   └── tasks
│   │       ├── git.yml
│   │       ├── main.yml
│   │       ├── packages_astra.yml
│   │       ├── packages_ubuntu.yml
│   │       └── pipx.yml
│   ├── docker
│   │   ├── defaults
│   │   │   └── main.yml
│   │   ├── handlers
│   │   │   └── main.yml
│   │   ├── README.md
│   │   └── tasks
│   │       ├── astra.yml
│   │       ├── main.yml
│   │       └── ubuntu.yml
│   ├── security
│   │   ├── defaults
│   │   │   └── main.yml
│   │   ├── handlers
│   │   │   └── main.yml
│   │   ├── README.md
│   │   └── tasks
│   │       ├── fail2ban.yml
│   │       ├── firewall.yml
│   │       ├── main.yml
│   │       ├── ssh.yml
│   │       └── sysctl.yml
│   └── users
│       ├── defaults
│       │   └── main.yml
│       ├── handlers
│       │   └── main.yml
│       ├── README.md
│       └── tasks
│           └── main.yml
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
astra-01 ansible_host=astra.example.local ansible_port=22 ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9

[ubuntu_hosts]
ubuntu-01 ansible_host=ubuntu.example.local ansible_port=22 ansible_user=ansible

[workstations:children]
astra_hosts
ubuntu_hosts
```

Пример для лабораторного стенда с пробросом портов:

```ini
[astra_hosts]
astra-02 ansible_host=192.0.2.10 ansible_port=2222 ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9

[ubuntu_hosts]
ubuntu-02 ansible_host=192.0.2.10 ansible_port=2224 ansible_user=ansible

[workstations:children]
astra_hosts
ubuntu_hosts
```

Значения вида `<host>`, `<ip>` или `<lab_host_ip>` в документации являются шаблонами. В реальном inventory угловые скобки не указываются.

Неправильно:

```ini
ubuntu-02 ansible_host=<192.168.0.110>
```

Правильно:

```ini
ubuntu-02 ansible_host=192.168.0.110
```

---

## 🧾 Пример group_vars

Пример `inventories/group_vars/workstations.yml`:

```yaml
---
users:
  - name: ansible
    comment: "Ansible automation user"
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
    comment: "Developer workstation user"
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

## 🏷️ Пример host_vars

Если в inventory указан хост:

```ini
ubuntu-02 ansible_host=192.0.2.10 ansible_port=2224 ansible_user=ansible
```

то файл host_vars должен называться:

```text
inventories/host_vars/ubuntu-02.yml
```

Пример:

```yaml
---
base_hostname: dev-ubuntu-02
```

Для Astra:

```ini
astra-02 ansible_host=192.0.2.10 ansible_port=2222 ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9
```

файл:

```text
inventories/host_vars/astra-02.yml
```

пример:

```yaml
---
base_hostname: dev-astra-02
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
| `users.yml` | Пользователи, SSH-ключи, sudo, password lock |
| `security.yml` | SSH hardening, fail2ban, firewall, sysctl |
| `docker.yml` | Docker Engine и Docker-доступ |
| `dev.yml` | Python-oriented dev-среда |

Для запуска только на конкретной машине используется `--limit`:

```bash
ansible-playbook playbooks/base.yml --limit ubuntu-02
ansible-playbook playbooks/users.yml --limit ubuntu-02
ansible-playbook playbooks/security.yml --limit ubuntu-02
ansible-playbook playbooks/docker.yml --limit ubuntu-02
ansible-playbook playbooks/dev.yml --limit ubuntu-02
```

---

## 🧪 Проверка после запуска

### Проверка доступности

```bash
ansible all -m ping
```

Для конкретной машины:

```bash
ansible ubuntu-02 -m ping
```

---

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

### Проверка users

```bash
ansible all -m command -a "getent passwd ansible"
ansible all -m command -a "getent passwd developer"
```

Проверка блокировки пароля:

```bash
ansible all -m command -a "passwd -S ansible" -b
ansible all -m command -a "passwd -S developer" -b
```

Ожидаемый статус при `password_lock: true`:

```text
L
```

---

### Проверка security

На целевой машине:

```bash
sudo sshd -T | grep -Ei "permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers"
sudo sshd -T | grep -Ei "permitemptypasswords|x11forwarding|allowtcpforwarding|maxsessions|maxstartups"
sudo fail2ban-client status
sudo ufw status verbose
```

Ожидаемо:

- SSH разрешает только заданных пользователей;
- password authentication отключена;
- root login отключён;
- fail2ban активен;
- firewall активен;
- входящие соединения запрещены по умолчанию;
- SSH-порт разрешён.

Проверка sysctl:

```bash
sysctl net.ipv4.tcp_syncookies
sysctl net.ipv4.conf.all.accept_redirects
cat /etc/sysctl.d/99-workstation-security.conf
```

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
- блокировка парольного входа у SSH-only пользователей;
- fail2ban для защиты от brute-force;
- firewall с политикой `deny incoming`;
- sysctl hardening;
- Docker-доступ только явно указанным пользователям;
- разделение пользователя Ansible и пользователя-разработчика;
- пользовательские Python CLI-инструменты устанавливаются через `pipx`, без изменения системного Python;
- реальные ключи и inventory-файлы не хранятся в Git.

---

## 🧠 Почему нет роли VS Code

В текущей версии проекта отдельная роль для установки Visual Studio Code не реализована намеренно.

Основная цель проекта — автоматизировать базовый и защищённый baseline рабочей станции разработчика:

- ОС;
- пользователи;
- SSH-доступ;
- sudo-модель;
- firewall;
- fail2ban;
- Docker;
- Python CLI-инструменты;
- Git;
- dev-среда.

Visual Studio Code относится к прикладному пользовательскому уровню. Его установка зависит от:

- наличия графической среды;
- политики организации;
- используемого дистрибутива;
- корпоративных репозиториев;
- способа распространения ПО;
- предпочтений разработчика.

Также не все целевые машины обязаны иметь GUI. Часть сценариев может выполняться на headless VM, где установка GUI-редактора не требуется.

Для Astra Linux установка VS Code может быть дополнительно связана с ограничениями корпоративной политики, сертифицированных репозиториев, доступных зависимостей и требований безопасности.

Минимальная dev-среда уже обеспечивается ролью `dev`, которая устанавливает Python CLI-инструменты и позволяет работать с любым редактором или IDE.

Поэтому VS Code вынесен в возможные направления развития как отдельная опциональная desktop-роль.

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
- строгую фиксацию версий всех Python CLI-инструментов;
- автоматизированный cloud-init/autoinstall provisioning.

---

## 📈 Планы развития

Возможные направления развития:

- опциональная роль `vscode` для desktop-профиля рабочей станции;
- интеграция с Ansible Vault;
- безопасное хранение и ротация ключей;
- поддержка Debian и Linux Mint;
- поддержка Red Hat-like систем;
- rootless Docker;
- version pinning для Python CLI-инструментов;
- cloud-init/autoinstall для полностью автоматизированного bootstrap;
- расширение Astra-specific security-проверок;
- auditd и централизованный сбор логов.

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

Каждая роль также содержит собственный README:

```text
roles/base/README.md
roles/users/README.md
roles/security/README.md
roles/docker/README.md
roles/dev/README.md
```

---

## 🎯 Текущий результат

Проект реализует полный цикл подготовки защищённой рабочей станции разработчика:

1. первичная подготовка машины;
2. создание служебного пользователя Ansible;
3. bootstrap Python для Astra Linux;
4. базовая настройка ОС;
5. управление пользователями;
6. применение политики безопасности;
7. установка Docker;
8. настройка Python-oriented dev-среды.

Финальное тестирование на новых чистых машинах Ubuntu и Astra Linux подтвердило работоспособность выбранной архитектуры.

После применения всех playbook'ов машина становится:

- управляемой;
- защищённой;
- воспроизводимо настроенной;
- готовой к Python-разработке.

---

## 📝 Примечание

Проект разрабатывается как практическая часть дипломной работы и демонстрирует подход к автоматизации настройки защищённых рабочих станций разработчиков.

Основной акцент сделан на:

- воспроизводимости;
- безопасности;
- разделении ответственности;
- поддержке нескольких Linux-дистрибутивов;
- реалистичном процессе подключения новых машин к управлению;
- возможности дальнейшего расширения проекта.