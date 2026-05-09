# Role: base

## Назначение

Роль `base` выполняет базовую настройку операционной системы и формирует минимальный унифицированный baseline рабочей станции.

Роль предназначена для начальной подготовки системы перед применением последующих ролей:

- `users`;
- `security`;
- `docker`;
- `dev`.

---

## Что делает роль

### Для Ubuntu

- обновляет пакетный кэш;
- устанавливает базовые системные пакеты;
- настраивает timezone;
- устанавливает и настраивает locale;
- централизованно настраивает hostname через `host_vars`;
- выполняет валидацию имени хоста;
- управляет записью в `/etc/hosts`.

---

### Для Debian

- обновляет пакетный кэш;
- устанавливает базовые системные пакеты;
- настраивает timezone;
- устанавливает пакет `locales`;
- генерирует и применяет locale;
- централизованно настраивает hostname через `host_vars`;
- выполняет валидацию имени хоста;
- управляет записью в `/etc/hosts`.

Debian-ветка реализована отдельно в файле:

```text
tasks/debian.yml
```

Так как Debian 12 близок к Ubuntu по пакетной базе и использует `apt`, роль может применять стандартные Ansible-модули:

```text
ansible.builtin.apt
community.general.timezone
ansible.builtin.locale_gen
ansible.builtin.lineinfile
```

---

### Для Astra Linux Orel

- обновляет пакетный кэш;
- устанавливает базовые системные пакеты;
- настраивает timezone;
- генерирует и применяет locale;
- использует отдельную реализацию через `raw` для совместимости с платформой;
- централизованно настраивает hostname через `host_vars`;
- выполняет валидацию имени хоста;
- управляет записью в `/etc/hosts`.

---

## Что не входит в роль

Роль `base` не выполняет:

- создание пользователей;
- настройку SSH-доступа;
- hardening системы;
- установку Docker;
- установку инструментов разработки.

Эти задачи вынесены в отдельные роли.

---

## Поддерживаемые платформы

На текущем этапе роль поддерживает:

- Ubuntu 24.04;
- Debian 12.13.0;
- Astra Linux Orel 2.12.

---

## Основные переменные

Переменные определяются в:

```text
defaults/main.yml
```

---

### `base_packages`

Список базовых пакетов, устанавливаемых на систему.

Пример:

```yaml
base_packages:
  - curl
  - wget
  - git
  - vim
  - ca-certificates
  - unzip
```

---

### `base_timezone`

Часовой пояс системы.

Пример:

```yaml
base_timezone: "Europe/Moscow"
```

---

### `base_locale`

Системная locale.

Пример:

```yaml
base_locale: "en_US.UTF-8"
```

---

## Hostname management

Роль поддерживает централизованную настройку hostname.

Hostname задаётся вручную на уровне inventory через `host_vars`.

Это позволяет:

- использовать уникальные имена для каждой машины;
- соблюдать единые правила именования;
- упростить администрирование;
- упростить анализ логов и результатов Ansible-запусков.

---

### Переменные hostname

```yaml
base_hostname: null
base_manage_hosts_file: true
```

---

### Поведение

Роль выполняет следующие действия:

- проверяет, задан ли `base_hostname`;
- выполняет валидацию hostname;
- применяет системный hostname;
- при включённом `base_manage_hosts_file` обновляет `/etc/hosts`.

---

### Пример host_vars для Ubuntu

```yaml
# inventories/host_vars/ubuntu.yml
base_hostname: dev-ubuntu-01
```

---

### Пример host_vars для Debian

```yaml
# inventories/host_vars/debian.yml
base_hostname: dev-debian-01
```

---

### Пример host_vars для Astra Linux

```yaml
# inventories/host_vars/astra.yml
base_hostname: dev-astra-01
```

---

## Структура задач

```text
tasks/
├── main.yml
├── common.yml
├── ubuntu.yml
├── debian.yml
└── astra.yml
```

Назначение файлов:

- `main.yml` — маршрутизация выполнения по дистрибутивам;
- `common.yml` — общие задачи, не зависящие от конкретной ОС;
- `ubuntu.yml` — Ubuntu-специфичная логика;
- `debian.yml` — Debian-специфичная логика;
- `astra.yml` — Astra Linux-специфичная логика.

---

## Маршрутизация задач

Роль выбирает нужный набор задач на основе Ansible facts.

Пример логики:

```yaml
- name: Include Ubuntu-specific base tasks
  ansible.builtin.import_tasks: ubuntu.yml
  when: ansible_facts['distribution'] == "Ubuntu"

- name: Include Debian-specific base tasks
  ansible.builtin.import_tasks: debian.yml
  when: ansible_facts['distribution'] == "Debian"

- name: Include Astra-specific base tasks
  ansible.builtin.import_tasks: astra.yml
  when: ansible_facts['distribution_release'] == "orel"
```

---

## Проверка определения ОС

Перед запуском роли можно проверить, как Ansible определяет систему:

```bash
ansible debian -m setup -a "filter=ansible_distribution*"
```

Для Debian 12.13.0 ожидаемый результат примерно такой:

```text
ansible_distribution: Debian
ansible_distribution_major_version: "12"
ansible_distribution_release: bookworm
ansible_distribution_version: "12.13"
```

---

## Пример inventory

### Ubuntu

```ini
[ubuntu_hosts]
ubuntu ansible_host=<ip_address> ansible_user=ansible
```

---

### Debian

```ini
[debian_hosts]
debian ansible_host=<ip_address> ansible_user=ansible
```

---

### Astra Linux

```ini
[astra_hosts]
astra ansible_host=<ip_address> ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9
```

---

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
- name: Apply base configuration
  hosts: workstations
  become: true

  roles:
    - base
```

---

## Запуск роли

Запуск для всех рабочих станций:

```bash
ansible-playbook playbooks/base.yml
```

Запуск только для Debian:

```bash
ansible-playbook playbooks/base.yml --limit debian
```

Если в inventory используется группа `debian_hosts`, можно запустить так:

```bash
ansible-playbook playbooks/base.yml --limit debian_hosts
```

---

## Особенности реализации

Роль использует единую naming policy для хостов:

```text
<purpose>-<os>-<number>
```

Примеры:

```text
dev-ubuntu-01
dev-debian-01
dev-astra-01
```

---

## Особенности Debian

Debian 12.13.0 использует релизную ветку:

```text
bookworm
```

Для базовой настройки Debian используется стандартный пакетный менеджер `apt`.

В отличие от Astra Linux, отдельный Python bootstrap для Debian в рамках роли `base` не требуется, если на машине уже доступен системный Python, необходимый для работы Ansible-модулей.

Для корректной работы роли на Debian должны быть доступны:

- SSH-доступ под пользователем `ansible`;
- права `sudo` у пользователя `ansible`;
- возможность выполнять команды через `become: true`;
- доступ к стандартным Debian-репозиториям.

---

## Особенности Astra Linux

На Astra Linux стандартный модуль `apt` используется ограниченно из-за платформенных особенностей Python-интерпретатора.

Поэтому часть базовой конфигурации реализована через `raw`.

Для Astra Linux в inventory может указываться отдельный Python-интерпретатор:

```ini
astra ansible_python_interpreter=/usr/local/bin/python3.9
```

---

## Ограничения текущей версии

- состав пакетов задаётся без жёсткой фиксации версий;
- дополнительные системные политики не применяются;
- роль не управляет пользователями;
- роль не настраивает SSH hardening;
- роль не устанавливает Docker и dev-инструменты.

---

## Итог

Роль `base` отвечает за первичную унификацию рабочих станций на разных Linux-дистрибутивах.

После выполнения роли система получает:

- базовый набор пакетов;
- корректный timezone;
- настроенную locale;
- централизованно заданный hostname;
- подготовленную основу для последующих ролей.

Финальная схема применения:

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
