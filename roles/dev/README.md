# Role: dev

## Назначение

Роль `dev` выполняет настройку Python-oriented среды разработки на рабочей станции.

Роль предназначена для подготовки рабочего окружения разработчика после применения базовых ролей:

- `base`;
- `users`;
- `security`;
- `docker`.

После выполнения роли пользователь получает готовый набор инструментов для Python-разработки.

---

## Место роли в общем пайплайне

Роль `dev` является финальной ролью в текущем пайплайне подготовки рабочей станции.

Общая схема применения ролей:

```text
bootstrap-ansible-user.sh
    ↓
base
    ↓
users
    ↓
security
    ↓
docker
    ↓
dev
    ↓
готовая рабочая станция
```

---

## Что делает роль

Роль выполняет следующие действия:

- устанавливает системные Python-пакеты;
- устанавливает build-зависимости для сборки Python-пакетов;
- устанавливает дополнительные CLI-инструменты;
- устанавливает и настраивает `pipx`;
- устанавливает Python CLI-инструменты через `pipx`;
- устанавливает `uv`;
- настраивает Git для пользователя-разработчика;
- поддерживает опциональные профили, например DB-клиенты и Jupyter.

---

## Что не входит в роль

Роль `dev` не выполняет:

- установку Docker;
- установку VS Code;
- установку PyCharm;
- установку Anaconda;
- установку серверов баз данных;
- настройку GUI;
- настройку корпоративного package registry;
- настройку shell prompt;
- настройку dotfiles;
- настройку SSH-доступа.

---

## Поддерживаемые платформы

На текущем этапе роль поддерживает:

- Ubuntu 24.04;
- Debian 12.13.0;
- Astra Linux Orel 2.12.

---

## Особенности платформ

### Ubuntu

На Ubuntu используется системный Python из репозиториев дистрибутива.

Для Ubuntu используется интерпретатор:

```yaml
dev_python_interpreter_ubuntu: python3
```

Роль устанавливает `python3`, `python3-pip`, `python3-venv`, `python3-dev`, `pipx`, build-зависимости и дополнительные CLI-инструменты.

---

### Debian 12.13.0

На Debian используется системный Python из репозиториев дистрибутива.

Для Debian 12 release codename:

```text
bookworm
```

Для Debian используется интерпретатор:

```yaml
dev_python_interpreter_debian: python3
```

Роль устанавливает `python3`, `python3-pip`, `python3-venv`, `python3-dev`, `pipx`, build-зависимости и дополнительные CLI-инструменты.

Python CLI-инструменты устанавливаются через:

```bash
python3 -m pipx install <tool>
```

Такой подход не конфликтует с системным Python и подходит для Debian 12.

---

### Astra Linux

На Astra Linux системный Python не используется как основа dev-среды, так как он может быть устаревшим.

Для разработки используется Python 3.9, установленный на этапе bootstrap:

```text
/opt/python/3.9
```

В ролях используется стабильная точка входа:

```text
/usr/local/bin/python3.9
```

Для Astra используется интерпретатор:

```yaml
dev_python_interpreter_astra: /usr/local/bin/python3.9
```

Системные зависимости могут устанавливаться через отдельную Astra-ветку, а Python CLI-инструменты устанавливаются через `pipx` на базе Python 3.9.

---

## Устанавливаемые Python CLI-инструменты

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

Назначение инструментов:

- `uv` — современный менеджер Python-пакетов и окружений;
- `ruff` — быстрый линтер и formatter-экосистема;
- `black` — форматирование кода;
- `isort` — сортировка импортов;
- `mypy` — статическая типизация;
- `pytest` — тестирование;
- `pre-commit` — управление pre-commit hooks;
- `poetry` — управление Python-проектами;
- `httpie` — удобный CLI-клиент для HTTP-запросов.

---

## Структура роли

```text
roles/dev/
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── packages_ubuntu.yml
│   ├── packages_debian.yml
│   ├── packages_astra.yml
│   ├── pipx.yml
│   └── git.yml
└── README.md
```

Назначение файлов:

- `defaults/main.yml` — переменные по умолчанию;
- `tasks/main.yml` — маршрутизация выполнения;
- `tasks/packages_ubuntu.yml` — установка системных пакетов на Ubuntu;
- `tasks/packages_debian.yml` — установка системных пакетов на Debian;
- `tasks/packages_astra.yml` — установка системных пакетов на Astra Linux, если используется отдельная Astra-ветка;
- `tasks/pipx.yml` — настройка pipx и установка Python CLI-инструментов;
- `tasks/git.yml` — настройка Git.

---

## Маршрутизация задач

Роль выбирает нужный набор задач на основе Ansible facts.

```yaml
- name: Include Ubuntu developer packages
  ansible.builtin.import_tasks: packages_ubuntu.yml
  when:
    - dev_enabled | bool
    - ansible_facts['distribution'] == "Ubuntu"

- name: Include Debian developer packages
  ansible.builtin.import_tasks: packages_debian.yml
  when:
    - dev_enabled | bool
    - ansible_facts['distribution'] == "Debian"

- name: Include pipx developer tools
  ansible.builtin.import_tasks: pipx.yml
  when: dev_enabled | bool

- name: Include Git configuration
  ansible.builtin.import_tasks: git.yml
  when:
    - dev_enabled | bool
    - dev_git_config_enabled | bool
```

---

## Основные переменные

Переменные определяются в:

```text
defaults/main.yml
```

### Включение роли

```yaml
dev_enabled: true
```

### Пользователи-разработчики

```yaml
dev_users:
  - developer
```

Список пользователей, которым будут установлены пользовательские dev-инструменты через `pipx`.

### Базовый путь домашних каталогов

```yaml
dev_home_base: /home
```

Используется для формирования путей вида:

```text
/home/<username>
```

### Python interpreter

```yaml
dev_python_interpreter_ubuntu: python3
dev_python_interpreter_debian: python3
dev_python_interpreter_astra: /usr/local/bin/python3.9
```

### Ubuntu Python packages

```yaml
dev_python_packages_ubuntu:
  - python3
  - python3-pip
  - python3-venv
  - python3-dev
  - pipx
```

### Debian Python packages

```yaml
dev_python_packages_debian:
  - python3
  - python3-pip
  - python3-venv
  - python3-dev
  - pipx
```

### Build dependencies

```yaml
dev_python_build_dependencies:
  - build-essential
  - gcc
  - g++
  - pkg-config
  - make
  - tar
  - libssl-dev
  - libffi-dev
  - zlib1g-dev
  - libbz2-dev
  - libreadline-dev
  - libsqlite3-dev
  - libncursesw5-dev
  - xz-utils
  - tk-dev
  - libxml2-dev
  - libxmlsec1-dev
  - liblzma-dev
```

### Extra packages

```yaml
dev_extra_packages:
  - jq
  - tree
  - htop
  - sqlite3
```

### pipx tools

```yaml
dev_pipx_tools:
  - uv
  - ruff
  - black
  - isort
  - mypy
  - pytest
  - pre-commit
  - poetry
  - httpie
```

### Опциональные DB-клиенты

```yaml
dev_install_db_clients: false

dev_db_client_packages:
  - postgresql-client
  - redis-tools
```

### Опциональный Jupyter

```yaml
dev_install_jupyter: false

dev_jupyter_tools:
  - jupyterlab
```

### Git configuration

```yaml
dev_git_config_enabled: false
dev_git_user_name: ""
dev_git_user_email: ""
```

Пример:

```yaml
dev_git_config_enabled: true
dev_git_user_name: "Developer"
dev_git_user_email: "developer@example.com"
```

---

## Рекомендуемое размещение переменных

Пользовательские данные рекомендуется задавать в inventory:

```text
inventories/group_vars/workstations.yml
```

Пример:

```yaml
dev_users:
  - developer

dev_git_config_enabled: true
dev_git_user_name: "Developer"
dev_git_user_email: "developer@example.com"
```

Если настройки отличаются по ОС, можно использовать отдельные файлы:

```text
inventories/group_vars/ubuntu_hosts.yml
inventories/group_vars/debian_hosts.yml
inventories/group_vars/astra_hosts.yml
```

---

## Пример inventory

### Ubuntu

```ini
[ubuntu_hosts]
ubuntu ansible_host=<ip_address> ansible_user=ansible
```

### Debian

```ini
[debian_hosts]
debian ansible_host=<ip_address> ansible_user=ansible
```

### Astra Linux

```ini
[astra_hosts]
astra ansible_host=<ip_address> ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9
```

### Общая группа рабочих станций

```ini
[workstations:children]
ubuntu_hosts
debian_hosts
astra_hosts
```

---

## Пример использования

```yaml
- name: Configure Python developer environment
  hosts: workstations
  become: true
  gather_facts: true

  roles:
    - dev
```

---

## Запуск роли

Запуск для всех рабочих станций:

```bash
ansible-playbook playbooks/dev.yml
```

Запуск только для Debian:

```bash
ansible-playbook playbooks/dev.yml --limit debian
```

Если в inventory используется группа `debian_hosts`, можно запустить так:

```bash
ansible-playbook playbooks/dev.yml --limit debian_hosts
```

---

## Проверка после установки

### Ubuntu

```bash
python3 --version
pipx list
uv --version
ruff --version
pytest --version
git config --global --list
```

### Debian

Проверка системных инструментов:

```bash
python3 --version
pipx --version
git --version
```

Проверка пользовательских pipx-инструментов от имени разработчика:

```bash
sudo -u developer -H python3 -m pipx list
sudo -u developer -H /home/developer/.local/bin/uv --version
sudo -u developer -H /home/developer/.local/bin/ruff --version
sudo -u developer -H /home/developer/.local/bin/pytest --version
```

Проверка через Ansible:

```bash
ansible debian -m command -a "python3 --version" -b
ansible debian -m command -a "pipx --version" -b
ansible debian -m command -a "git --version" -b
ansible debian -m command -a "/home/developer/.local/bin/uv --version" -b --become-user developer
```

### Astra Linux

```bash
/usr/local/bin/python3.9 --version
/usr/local/bin/python3.9 -m pipx list
~/.local/bin/uv --version
~/.local/bin/ruff --version
git config --global --list
```

---

## Проверка Debian

Перед запуском роли на Debian можно проверить определение ОС:

```bash
ansible debian -m setup -a "filter=ansible_distribution*"
```

Ожидаемые значения для Debian 12.13.0:

```text
ansible_distribution: Debian
ansible_distribution_major_version: "12"
ansible_distribution_release: bookworm
ansible_distribution_version: "12.13"
```

Проверить apt-пакеты:

```bash
ansible debian -m command -a "dpkg -l | grep -E 'python3|python3-pip|python3-venv|python3-dev|pipx'" -b
```

---

## Важное замечание про pipx и PATH

`pipx` устанавливает пользовательские CLI-инструменты в:

```text
/home/<user>/.local/bin
```

Например:

```text
/home/developer/.local/bin/uv
/home/developer/.local/bin/ruff
/home/developer/.local/bin/pytest
```

После установки `pipx ensurepath` добавляет этот путь в shell-конфигурацию пользователя, но текущая активная сессия может не увидеть новый PATH сразу.

Если команда `uv` не находится, можно проверить полный путь:

```bash
/home/developer/.local/bin/uv --version
```

Или открыть новую shell/SSH-сессию.

---

## Идемпотентность

Роль должна быть пригодна для повторного запуска.

Ожидаемый результат при повторном применении без изменения переменных:

```text
failed=0
unreachable=0
```

Желательное состояние:

```text
changed=0
```

Некоторые задачи могут показывать `changed`, если `pipx` или пакетный менеджер обновили состояние окружения. В этом случае нужно проверять фактическое наличие инструментов.

---

## Особенности воспроизводимости

Версии Python CLI-инструментов могут отличаться между Ubuntu, Debian и Astra Linux, так как:

- Ubuntu 24.04 использует Python 3.12;
- Debian 12 использует системный Python из ветки Bookworm;
- Astra Linux использует Python 3.9;
- некоторые Python-пакеты выбирают разные последние совместимые версии.

Для строгой воспроизводимости возможно закрепление версий инструментов в `dev_pipx_tools`, например:

```yaml
dev_pipx_tools:
  - uv==0.11.8
  - ruff==0.15.12
  - pytest==8.4.2
```

В текущей версии роль использует актуальные совместимые версии инструментов.

---

## Особенности безопасности

- инструменты устанавливаются в пользовательское окружение через `pipx`;
- глобальная установка Python-пакетов через `pip` не используется;
- системный Python не загрязняется пакетами CLI-инструментов;
- пользовательские инструменты устанавливаются только для пользователей из `dev_users`;
- список пользователей задаётся явно.

---

## Ограничения текущей версии

- версии Python CLI-инструментов не закреплены;
- Node.js не устанавливается;
- нет разделения dev-профилей по специализациям;
- не настраиваются IDE;
- не настраиваются dotfiles;
- не настраивается корпоративный Python package registry;
- не настраиваются pre-commit hooks для конкретного проекта.

---

## Итог

Роль `dev` формирует рабочее Python-окружение разработчика:

- устанавливает системный Python и dev-зависимости;
- устанавливает build-инструменты;
- устанавливает дополнительные CLI-пакеты;
- настраивает `pipx`;
- устанавливает Python CLI-инструменты;
- может настроить Git;
- поддерживает Ubuntu, Debian и Astra Linux.

Финальная оценка поддержки:

```text
Ubuntu 24.04       -> полная поддержка
Debian 12.13.0     -> полная поддержка
Astra Linux Orel   -> поддержка с особенностями Python 3.9
```
