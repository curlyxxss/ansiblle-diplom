# 🛡️Automated Secure Developer Workstation Setup

## 📌 Описание проекта

Проект представляет собой систему автоматизированной подготовки защищённых рабочих станций разработчиков с использованием Ansible.

Цель проекта — обеспечить воспроизводимую, управляемую и безопасную настройку Linux-станций для разработки: от первичного подключения новой машины до установки пользователей, security baseline, Docker и Python-oriented dev-среды.

Проект ориентирован на корпоративный сценарий, где важно:

- минимизировать ручную настройку рабочих станций;
- обеспечить единый baseline конфигурации;
- разделить служебный административный доступ и пользовательскую работу;
- повысить безопасность SSH-доступа;
- быстро подготовить рабочую станцию к Python-разработке;
- сохранить возможность расширения под новые дистрибутивы и роли.

---

## 🧩 Поддерживаемые платформы

Проект проверен на чистых виртуальных машинах:

- Ubuntu 24.04;
- Debian 12.13.0;
- Astra Linux Orel 2.12.

Особенности поддержки:

```text
Ubuntu 24.04       -> полная поддержка
Debian 12.13.0     -> полная поддержка
Astra Linux Orel   -> поддержка с особенностями Python и Docker
```

Для Astra Linux используется отдельный bootstrap Python 3.9, так как системный Python не подходит для всех задач проекта.

---

## 🏗️ Архитектура

Проект построен на Ansible-ролях.

| Роль | Назначение |
|---|---|
| `base` | Базовая настройка ОС: пакеты, timezone, locale, hostname |
| `users` | Пользователи, SSH-ключи, sudo, блокировка паролей |
| `security` | SSH hardening, fail2ban, firewall, sysctl hardening |
| `docker` | Установка Docker Engine и настройка доступа к Docker |
| `dev` | Python-oriented dev-среда, pipx-инструменты, Git |

Рекомендуемый порядок применения:

```text
base -> users -> security -> docker -> dev
```

---

## 👥 Модель пользователей

В проекте используется разделение служебного пользователя Ansible и пользователя-разработчика.

### 🔧 `ansible`

Служебный пользователь автоматизации.

Используется для:

- подключения Ansible к целевым машинам;
- выполнения playbook'ов;
- выполнения задач с `become: true`.

Особенности:

- SSH-доступ по ключу;
- sudo-доступ;
- парольный вход заблокирован;
- не используется для ежедневной работы.

### 👨‍💻 `developer`

Пользователь-разработчик.

Используется для:

- повседневной работы;
- запуска Docker;
- использования Python CLI-инструментов;
- работы с Git.

Особенности:

- SSH-доступ по ключу;
- без sudo-доступа по умолчанию;
- Docker-доступ выдаётся через группу `docker`;
- dev-инструменты устанавливаются в пользовательское окружение через `pipx`.

---

## 🚀 Pipeline подготовки новой машины

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
Bootstrap Python для Astra Linux, если требуется
    ↓
Запуск Ansible playbook'ов
    ↓
Проверка результата
    ↓
Готовая рабочая станция разработчика
```

Bootstrap пользователя Ansible выполняется скриптом:

```text
scripts/bootstrap-ansible-user.sh
```

Пример запуска:

```bash
sudo PUBLIC_KEY_FILE=/tmp/ansible.pub bash scripts/bootstrap-ansible-user.sh
```

Для Astra Linux дополнительно используется:

```text
scripts/install-python.sh
```

Он устанавливает Python 3.9 и создаёт стабильную точку входа:

```text
/usr/local/bin/python3.9
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
│   │   ├── debian.yml
│   │   ├── debian.yml.example
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
│   │   ├── README.md
│   │   └── tasks
│   │       ├── astra.yml
│   │       ├── common.yml
│   │       ├── debian.yml
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
│   │       ├── packages_debian.yml
│   │       ├── packages_ubuntu.yml
│   │       └── pipx.yml
│   ├── docker
│   │   ├── defaults
│   │   │   └── main.yml
│   │   ├── README.md
│   │   └── tasks
│   │       ├── astra.yml
│   │       ├── debian.yml
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
│       ├── README.md
│       └── tasks
│           └── main.yml
└── scripts
    ├── bootstrap-ansible-user.sh
    ├── install-python.sh
    └── verify-workstation.sh
```

В Git должны храниться `.example`-файлы. Реальные inventory-файлы и реальные SSH-ключи не должны попадать в репозиторий.

---

## ⚙️ Подготовка локальных файлов

После клонирования репозитория нужно создать локальные конфигурационные файлы из шаблонов:

```bash
cp inventories/inventory.ini.example inventories/inventory.ini
cp inventories/group_vars/workstations.yml.example inventories/group_vars/workstations.yml
```

Для host_vars:

```bash
cp inventories/host_vars/ubuntu.yml.example inventories/host_vars/ubuntu.yml
cp inventories/host_vars/debian.yml.example inventories/host_vars/debian.yml
cp inventories/host_vars/astra.yml.example inventories/host_vars/astra.yml
```

Публичные ключи:

```bash
cp ~/.ssh/ansible.pub files/ssh_keys/ansible.pub
cp ~/.ssh/developer.pub files/ssh_keys/developer.pub
```

---

## 🧾 Пример inventory

```ini
[ubuntu_hosts]
ubuntu ansible_host=192.168.0.101 ansible_user=ansible

[debian_hosts]
debian ansible_host=192.168.0.110 ansible_user=ansible

[astra_hosts]
astra ansible_host=192.168.0.120 ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9

[workstations:children]
ubuntu_hosts
debian_hosts
astra_hosts
```

Если используется нестандартный SSH-порт:

```ini
debian ansible_host=192.168.0.110 ansible_port=2222 ansible_user=ansible
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

Для Debian 12 рекомендуется использовать fail2ban через systemd journal:

```yaml
security_fail2ban_backend: systemd
security_fail2ban_sshd_logpath: ""
```

---

## 🏷️ Пример host_vars

Hostname задаётся на уровне `host_vars`.

Пример `inventories/host_vars/debian.yml`:

```yaml
---
base_hostname: dev-debian-01
```

Пример `inventories/host_vars/ubuntu.yml`:

```yaml
---
base_hostname: dev-ubuntu-01
```

Пример `inventories/host_vars/astra.yml`:

```yaml
---
base_hostname: dev-astra-01
```

Имя файла в `host_vars` должно соответствовать имени хоста в inventory.

---

## ▶️ Запуск playbook'ов

Рекомендуемый порядок:

```bash
ansible-playbook playbooks/base.yml
ansible-playbook playbooks/users.yml
ansible-playbook playbooks/security.yml
ansible-playbook playbooks/docker.yml
ansible-playbook playbooks/dev.yml
```

Запуск только для одной машины:

```bash
ansible-playbook playbooks/base.yml --limit debian
ansible-playbook playbooks/users.yml --limit debian
ansible-playbook playbooks/security.yml --limit debian
ansible-playbook playbooks/docker.yml --limit debian
ansible-playbook playbooks/dev.yml --limit debian
```

Для `security.yml` рекомендуется использовать:

```yaml
force_handlers: true
```

Это важно, потому что роль изменяет SSH-конфигурацию, и handler перезапуска SSH должен выполниться даже при ошибке на другом хосте.

---

## 🧪 Проверка

Базовая проверка Ansible:

```bash
ansible all -m ping
ansible all -m command -a "whoami"
ansible all -m command -a "whoami" -b
```

Ожидаемо:

```text
whoami без become -> ansible
whoami с become  -> root
```

Проверка фактов ОС:

```bash
ansible all -m setup -a "filter=ansible_distribution*"
```

Проверка всей рабочей станции:

```bash
ansible all -m script -a "scripts/verify-workstation.sh"
```

Проверка конкретной машины:

```bash
ansible debian -m script -a "scripts/verify-workstation.sh"
```

---

## 🧠 Что проверяет verify-workstation.sh

Скрипт проверки контролирует:

- hostname;
- пользователя Ansible;
- ОС;
- timezone и locale;
- наличие пользователей `ansible` и `developer`;
- sudo/become-доступ;
- блокировку паролей;
- SSH hardening;
- fail2ban;
- ufw;
- sysctl hardening;
- Docker;
- Docker Compose plugin;
- Python dev-инструменты;
- Git-конфигурацию пользователя-разработчика.

---

## 🔐 Безопасность

Проект реализует несколько уровней защиты:

- SSH-доступ только по ключам;
- отключение password authentication;
- запрет root login;
- опциональное ограничение SSH через `AllowUsers`;
- блокировка парольного входа у SSH-only пользователей;
- fail2ban для защиты от brute-force;
- firewall с политикой `deny incoming`;
- sysctl hardening;
- Docker-доступ только явно указанным пользователям;
- разделение пользователя Ansible и пользователя-разработчика;
- установка Python CLI-инструментов через `pipx`;
- исключение реальных ключей и inventory из Git.

---

## ⚠️ Важные замечания

### AllowUsers

По умолчанию `security_ssh_allow_users` может быть пустым:

```yaml
security_ssh_allow_users: []
```

Пустой список означает, что роль не ограничивает SSH-доступ через директиву `AllowUsers`.

Если ограничение включено, нужно обязательно добавить туда пользователя `ansible`, иначе можно потерять SSH-доступ для Ansible.

### Docker group

Пользователь в группе `docker` фактически получает возможность повысить привилегии до root через Docker. Поэтому в `docker_users` нужно добавлять только тех пользователей, которым действительно нужен Docker.

### Debian и fail2ban

На Debian 12 в минимальной установке может отсутствовать `/var/log/auth.log`. Для таких систем рекомендуется использовать:

```yaml
security_fail2ban_backend: systemd
security_fail2ban_sshd_logpath: ""
```

### Astra Linux

Astra Linux требует отдельного Python bootstrap. Также Docker на Astra может иметь ограничения по версии и доступности современных плагинов.

---

## 📚 Документация

Дополнительные документы:

```text
docs/bootstrap-ansible-user.md
docs/bootstrap-astra.md
docs/machine-initialization-pipeline.md
```

README отдельных ролей:

```text
roles/base/README.md
roles/users/README.md
roles/security/README.md
roles/docker/README.md
roles/dev/README.md
```

---

## Ограничения текущей версии

На текущем этапе проект не реализует:

- rootless Docker;
- корпоративный Docker registry;
- централизованный сбор логов;
- auditd/SIEM-интеграцию;
- установку VS Code или других GUI-инструментов;
- поддержку Red Hat-like систем;
- строгую фиксацию версий всех Python CLI-инструментов;
- полностью автоматизированный cloud-init/autoinstall provisioning.

---

## 📈  Планы развития

Возможные направления развития:

- интеграция с Ansible Vault;
- безопасное хранение и ротация ключей;
- поддержка Linux Mint;
- поддержка Red Hat-like систем;
- rootless Docker;
- version pinning для Python CLI-инструментов;
- cloud-init/autoinstall для полного bootstrap;
- расширение Astra-specific security-проверок;
- auditd и централизованный сбор логов;
- отдельная desktop-роль для GUI-инструментов.

---

## 🎯 Итог

Проект реализует полный цикл подготовки защищённой рабочей станции разработчика:

1. первичная подготовка машины;
2. создание служебного пользователя Ansible;
3. bootstrap Python для Astra Linux;
4. базовая настройка ОС;
5. управление пользователями;
6. применение политики безопасности;
7. установка Docker;
8. настройка Python-oriented dev-среды;
9. финальная проверка результата.

После применения всех playbook'ов машина становится управляемой, защищённой, воспроизводимо настроенной и готовой к Python-разработке.
