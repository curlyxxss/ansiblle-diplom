# Role: docker

## Назначение

Роль `docker` выполняет установку и базовую настройку Docker Engine на рабочих станциях.

Роль предназначена для:

- подготовки среды контейнеризации;
- обеспечения возможности запуска контейнеров разработчиками;
- унификации Docker-окружения;
- установки Docker из официального Docker apt-репозитория там, где это возможно.

---

## Место роли в общем пайплайне

Роль `docker` запускается после ролей `base`, `users` и `security`.

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

- удаляет конфликтующие Docker-пакеты;
- устанавливает зависимости для подключения apt-репозитория;
- добавляет официальный GPG-ключ Docker;
- добавляет официальный Docker apt-репозиторий;
- устанавливает Docker Engine;
- устанавливает Docker CLI;
- устанавливает containerd;
- устанавливает Docker Buildx plugin;
- устанавливает Docker Compose plugin;
- запускает и включает сервис Docker;
- добавляет явно указанных пользователей в группу `docker`.

---

## Что не входит в роль

Роль `docker` не выполняет:

- настройку Docker registry;
- настройку `/etc/docker/daemon.json`;
- настройку rootless Docker;
- установку Kubernetes;
- установку Minikube или kind;
- настройку Docker networks;
- настройку Docker volumes;
- установку `docker-compose` как standalone binary;
- автоматическое добавление всех пользователей в группу `docker`.

Эти задачи могут быть вынесены в отдельные роли или реализованы в следующих версиях проекта.

---

## Поддерживаемые платформы

На текущем этапе роль поддерживает:

- Ubuntu 24.04;
- Debian 12.13.0;
- Astra Linux Orel 2.12.

---

## Ubuntu 24.04

На Ubuntu используется официальный Docker apt-репозиторий:

```text
https://download.docker.com/linux/ubuntu
```

Роль выполняет:

- добавление GPG-ключа Docker;
- добавление apt-репозитория Docker;
- установку пакетов Docker;
- запуск и включение сервиса Docker;
- добавление пользователей в группу `docker`.

Официальная инструкция Docker для Ubuntu использует apt-репозиторий Docker, GPG-ключ в `/etc/apt/keyrings/docker.asc` и установку пакетов `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`.

---

## Debian 12.13.0

На Debian используется официальный Docker apt-репозиторий:

```text
https://download.docker.com/linux/debian
```

Для Debian 12 используется release codename:

```text
bookworm
```

Роль выполняет:

- удаление конфликтующих пакетов;
- установку `ca-certificates` и `curl`;
- создание директории `/etc/apt/keyrings`;
- загрузку GPG-ключа Docker;
- добавление Docker apt-репозитория через `deb822_repository`;
- обновление apt cache;
- установку Docker-пакетов;
- запуск и включение сервиса Docker;
- добавление пользователей в группу `docker`.

Docker официально поддерживает Debian Bookworm 12 и установку через apt-репозиторий Docker.

---

## Astra Linux Orel

Для Astra Linux реализована отдельная ветка установки.

Особенности:

- установка может использовать Debian-based подход;
- доступная версия Docker Engine может быть старее, чем на Ubuntu/Debian;
- современные плагины `docker-buildx-plugin` и `docker-compose-plugin` могут быть недоступны;
- поддержка Astra считается ограниченной по сравнению с Ubuntu/Debian.

---

## Ограничения Astra Linux

Для Astra Linux возможны ограничения:

- устаревшая версия Docker Engine;
- отсутствие современных возможностей Buildx;
- отсутствие Compose plugin;
- потенциальные проблемы с безопасностью и поддержкой;
- неполное соответствие baseline корпоративной среды.

Для production-использования Docker предпочтительнее использовать Ubuntu или Debian, если требования проекта позволяют выбрать ОС.

---

## Структура роли

```text
roles/docker/
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── ubuntu.yml
│   ├── debian.yml
│   └── astra.yml
└── README.md
```

Назначение файлов:

- `defaults/main.yml` — переменные по умолчанию;
- `handlers/main.yml` — обработчики, если они используются;
- `tasks/main.yml` — маршрутизация по дистрибутивам;
- `tasks/ubuntu.yml` — установка Docker на Ubuntu;
- `tasks/debian.yml` — установка Docker на Debian;
- `tasks/astra.yml` — установка Docker на Astra Linux.

---

## Маршрутизация задач

Роль выбирает нужный набор задач на основе Ansible facts.

Пример логики:

```yaml
- name: Include Ubuntu Docker tasks
  ansible.builtin.import_tasks: ubuntu.yml
  when: ansible_facts['distribution'] == "Ubuntu"

- name: Include Debian Docker tasks
  ansible.builtin.import_tasks: debian.yml
  when: ansible_facts['distribution'] == "Debian"

- name: Include Astra Docker tasks
  ansible.builtin.import_tasks: astra.yml
  when: ansible_facts['distribution_release'] | default('') == "orel"
```

---

## Основные переменные

Переменные определяются в:

```text
defaults/main.yml
```

---

### Включение роли

```yaml
docker_enabled: true
```

Если значение `false`, роль не выполняет установку Docker.

---

### Пользователи Docker

```yaml
docker_users: []
```

Список пользователей, которые будут добавлены в группу `docker`.

Пример:

```yaml
docker_users:
  - developer
```

Важно: добавление пользователя в группу `docker` фактически даёт ему возможность получать root-доступ через Docker. Поэтому список пользователей должен задаваться явно.

---

### Пакеты Docker

```yaml
docker_packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - docker-compose-plugin
```

Эти пакеты используются для Ubuntu и Debian при установке из официального Docker apt-репозитория.

---

### Конфликтующие пакеты

```yaml
docker_remove_conflicting_packages:
  - docker.io
  - docker-compose
  - docker-compose-v2
  - docker-doc
  - podman-docker
  - containerd
  - runc
```

Перед установкой официальных Docker-пакетов роль удаляет пакеты, которые могут конфликтовать с Docker Engine из официального репозитория.

---

### Apt keyrings

```yaml
docker_apt_keyrings_dir: /etc/apt/keyrings
docker_apt_gpg_key_path: /etc/apt/keyrings/docker.asc
```

Эти переменные задают расположение GPG-ключа Docker.

---

### Ubuntu repository

```yaml
docker_ubuntu_repo_url: https://download.docker.com/linux/ubuntu
docker_ubuntu_gpg_url: https://download.docker.com/linux/ubuntu/gpg
```

---

### Debian repository

```yaml
docker_debian_repo_url: https://download.docker.com/linux/debian
docker_debian_gpg_url: https://download.docker.com/linux/debian/gpg
```

---

### Astra настройки

```yaml
docker_astra_use_official_repo: true
docker_astra_debian_codename: "stretch"
```

---

## Пример конфигурации

Пример `inventories/group_vars/workstations.yml`:

```yaml
docker_enabled: true

docker_users:
  - developer
```

Если Docker нужен только на части машин, переменные можно задавать точечно в `host_vars` или отдельных `group_vars`.

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
- name: Install Docker
  hosts: workstations
  become: true
  gather_facts: true

  roles:
    - docker
```

---

## Запуск роли

Запуск для всех рабочих станций:

```bash
ansible-playbook playbooks/docker.yml
```

Запуск только для Debian:

```bash
ansible-playbook playbooks/docker.yml --limit debian
```

Если в inventory используется группа `debian_hosts`, можно запустить так:

```bash
ansible-playbook playbooks/docker.yml --limit debian_hosts
```

---

## Проверка после установки

Проверить версию Docker:

```bash
ansible all -m command -a "docker --version" -b
```

Проверить Docker Compose plugin:

```bash
ansible all -m command -a "docker compose version" -b
```

Проверить Docker Buildx plugin:

```bash
ansible all -m command -a "docker buildx version" -b
```

Проверить состояние сервиса:

```bash
ansible all -m command -a "systemctl is-active docker" -b
ansible all -m command -a "systemctl is-enabled docker" -b
```

Ожидаемый результат:

```text
active
enabled
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

Проверить, что репозиторий Docker добавлен:

```bash
ansible debian -m command -a "ls -l /etc/apt/sources.list.d/" -b
```

Проверить пакеты Docker:

```bash
ansible debian -m command -a "dpkg -l | grep -E 'docker-ce|containerd.io|docker-buildx-plugin|docker-compose-plugin'" -b
```

---

## Важное замечание про группу docker

Пользователь, добавленный в группу `docker`, может управлять Docker daemon.

Это означает, что такой пользователь фактически получает возможность повысить привилегии до root через контейнеры.

Поэтому:

- не нужно добавлять всех пользователей в группу `docker`;
- список должен быть задан явно;
- обычно достаточно добавить пользователя-разработчика;
- служебного пользователя `ansible` добавлять в группу `docker` необязательно, так как он выполняет задачи через `become: true`.

После добавления пользователя в группу `docker` текущая сессия пользователя может не увидеть новую группу сразу.

Нужно выполнить одно из действий:

- выйти из системы и войти заново;
- открыть новую SSH-сессию;
- перезагрузить машину;
- временно использовать `newgrp docker`.

Проверка:

```bash
groups developer
```

---

## Docker и firewall

Docker может напрямую управлять правилами iptables.

Если на машине используется `ufw`, нужно учитывать, что опубликованные Docker-порты могут обходить обычные правила `ufw`.

Это не ошибка роли, а особенность взаимодействия Docker и Linux firewall.

При необходимости более строгий контроль сетевого доступа к контейнерам нужно реализовывать отдельно через:

- Docker daemon configuration;
- `DOCKER-USER` chain;
- отдельные firewall rules;
- отказ от публикации портов наружу без необходимости.

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

Некоторые задачи могут показывать `changed`, если пакетный менеджер обновил состояние кэша или сервис изменил состояние. В этом случае нужно проверять фактическое состояние Docker.

---

## Особенности безопасности

- доступ к Docker предоставляется только через группу `docker`;
- список пользователей задаётся явно;
- не используется автоматическое добавление всех пользователей;
- учитывается риск повышения привилегий через Docker;
- роль не включает rootless Docker;
- роль не настраивает registry credentials.

---

## Ограничения текущей версии

- Astra Linux не поддерживает актуальную версию Docker на уровне Ubuntu/Debian;
- отсутствует унификация версий между платформами;
- не настраивается `/etc/docker/daemon.json`;
- не настраивается rootless Docker;
- не настраивается proxy для Docker daemon;
- не настраивается private registry;
- не настраиваются политики логирования Docker.

---

## Итог

Роль `docker` формирует базовую контейнерную среду рабочей станции:

- устанавливает Docker Engine;
- устанавливает Docker CLI;
- устанавливает containerd;
- устанавливает Buildx и Compose plugin на поддерживаемых системах;
- запускает и включает Docker daemon;
- добавляет явно указанных пользователей в группу `docker`.

Финальная оценка поддержки:

```text
Ubuntu 24.04       -> полная поддержка
Debian 12.13.0     -> полная поддержка
Astra Linux Orel   -> ограниченная поддержка
```
