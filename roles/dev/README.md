# Role: dev

## Назначение

Роль `dev` выполняет настройку Python-oriented среды разработки на рабочей станции.

Роль предназначена для подготовки рабочего окружения разработчика после применения базовых ролей:

- `base`
- `users`
- `security`
- `docker`

После выполнения роли пользователь получает готовый набор инструментов для Python-разработки.

---

## Что делает роль

Роль выполняет:

- установку системных Python-пакетов;
- установку build-зависимостей для сборки Python-пакетов;
- установку дополнительных CLI-инструментов;
- настройку `pipx`;
- установку Python CLI-инструментов через `pipx`;
- установку `uv`;
- настройку Git для разработчика;
- поддержку опциональных профилей.

---

## Поддерживаемые платформы

- Ubuntu 24.04
- Astra Linux Orel

---

## Особенности платформ

### Ubuntu

На Ubuntu используется системный Python из репозиториев дистрибутива.

Роль устанавливает:

- `python3`
- `python3-pip`
- `python3-venv`
- `python3-dev`
- `pipx`
- build-зависимости
- дополнительные CLI-инструменты

### Astra Linux

На Astra Linux системный Python не используется как основа dev-среды, так как он устарел.

Для разработки используется Python 3.9, установленный на этапе bootstrap:

```text
/opt/python/3.9
````

В ролях используется стабильная точка входа:

```text
/usr/local/bin/python3.9
```

Системные зависимости устанавливаются через `apt-get` с использованием `raw`, а Python CLI-инструменты устанавливаются через `pipx` на базе Python 3.9.

---

## Устанавливаемые Python CLI-инструменты

По умолчанию через `pipx` устанавливаются:

* `uv`
* `ruff`
* `black`
* `isort`
* `mypy`
* `pytest`
* `pre-commit`
* `poetry`
* `httpie`

Назначение инструментов:

* `uv` — современный менеджер Python-пакетов и окружений;
* `ruff` — быстрый линтер и formatter-экосистема;
* `black` — форматирование кода;
* `isort` — сортировка импортов;
* `mypy` — статическая типизация;
* `pytest` — тестирование;
* `pre-commit` — управление pre-commit hooks;
* `poetry` — управление Python-проектами;
* `httpie` — удобный CLI-клиент для HTTP-запросов.

---

## Основные переменные

Определяются в `defaults/main.yml`.

### Включение роли

```yaml
dev_enabled: true
```

---

### Пользователи разработчики

```yaml
dev_users: []
```

Список пользователей, которым будут установлены пользовательские dev-инструменты.

Пример:

```yaml
dev_users:
  - devuser
```

---

### Python interpreter

```yaml
dev_python_interpreter_ubuntu: python3
dev_python_interpreter_astra: /usr/local/bin/python3.9
```

---

### Ubuntu Python packages

```yaml
dev_python_packages_ubuntu:
  - python3
  - python3-pip
  - python3-venv
  - python3-dev
  - pipx
```

---

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

---

### Extra packages

```yaml
dev_extra_packages:
  - jq
  - tree
  - htop
  - sqlite3
```

---

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

---

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
  - devuser

dev_git_config_enabled: true
dev_git_user_name: "Developer"
dev_git_user_email: "developer@example.com"
```

---

## Структура задач

```text
tasks/
├── main.yml
├── packages_ubuntu.yml
├── packages_astra.yml
├── pipx.yml
└── git.yml
```

* `packages_ubuntu.yml` — установка системных пакетов на Ubuntu;
* `packages_astra.yml` — установка системных пакетов на Astra;
* `pipx.yml` — настройка pipx и установка Python CLI-инструментов;
* `git.yml` — настройка Git;
* `main.yml` — маршрутизация выполнения.

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

### Astra Linux

```bash
/usr/local/bin/python3.9 --version
/usr/local/bin/python3.9 -m pipx list
~/.local/bin/uv --version
~/.local/bin/ruff --version
git config --global --list
```

---

## Идемпотентность

Роль проверена повторным запуском.

Ожидаемый результат при повторном применении:

```text
changed=0
failed=0
unreachable=0
```

---

## Особенности воспроизводимости

Версии Python CLI-инструментов могут отличаться между Ubuntu и Astra Linux, так как:

* Ubuntu использует Python 3.12;
* Astra Linux использует Python 3.9;
* некоторые Python-пакеты выбирают разные последние совместимые версии.

Для строгой воспроизводимости возможно закрепление версий инструментов в `dev_pipx_tools`, например:

```yaml
dev_pipx_tools:
  - uv==0.11.8
  - ruff==0.15.12
  - pytest==8.4.2
```

В текущей версии роль использует актуальные совместимые версии инструментов.

---

## Что не входит в роль

Роль `dev` не выполняет:

* установку Docker;
* установку VS Code;
* установку PyCharm;
* установку Anaconda;
* установку серверов баз данных;
* настройку GUI;
* настройку корпоративного package registry.


---

## Ограничения текущей версии

* версии Python CLI-инструментов не закреплены;
* Node.js не устанавливается;
* нет разделения dev-профилей по специализациям.


