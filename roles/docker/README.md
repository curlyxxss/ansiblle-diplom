# Role: docker

## 📌 Назначение

Роль `docker` выполняет установку и настройку Docker Engine на рабочих станциях.

Роль предназначена для:

* подготовки среды контейнеризации;
* обеспечения возможности запуска контейнеров разработчиками;
* унификации Docker-окружения.

---

## 🎯 Что делает роль

### Общий функционал

* удаляет конфликтующие пакеты Docker;
* устанавливает Docker Engine;
* запускает и включает сервис;
* добавляет пользователей в группу `docker`.

---

## 🐧 Ubuntu 24.04 (полная поддержка)

На Ubuntu используется официальный Docker repository.

Роль выполняет:

* добавление GPG ключа Docker;
* добавление apt-репозитория Docker;
* установку пакетов:

  * docker-ce
  * docker-ce-cli
  * containerd.io
  * docker-buildx-plugin
  * docker-compose-plugin;
* запуск и включение сервиса;
* добавление пользователей в группу `docker`.

---

## 🛡 Astra Linux Orel (ограниченная поддержка)

Для Astra Linux была реализована установка через официальный Debian-based подход.

Результат:

* Docker Engine устанавливается;
* доступная версия — 19.03.x;
* отсутствуют современные плагины:

  * docker-buildx-plugin
  * docker-compose-plugin.

---

## ⚠️ Ограничения Astra

* устаревшая версия Docker Engine;
* отсутствие современных возможностей (Buildx, Compose plugin);
* потенциальные проблемы с безопасностью и поддержкой;
* не соответствует baseline корпоративной среды.

---

## 📊 Вывод

* Ubuntu является полностью поддерживаемой платформой для Docker;
* Astra Linux поддерживается ограниченно;
* для production-использования Docker рекомендуется использовать Ubuntu.

---

## ⚙️ Основные переменные

Определяются в `defaults/main.yml`.

### Включение роли

```yaml
docker_enabled: true
```

---

### Пользователи Docker

```yaml
docker_users: []
```

Список пользователей, которые будут добавлены в группу `docker`.

Пример:

```yaml
docker_users:
  - devuser
```

---

### Пакеты (Ubuntu)

```yaml
docker_packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - docker-compose-plugin
```

---

### Astra настройки

```yaml
docker_astra_use_official_repo: true
docker_astra_debian_codename: "stretch"
```

---

## 🚀 Пример использования

```yaml
- name: Install Docker
  hosts: workstations
  become: true

  roles:
    - docker
```

---

## 🔒 Особенности безопасности

* доступ к Docker предоставляется только через группу `docker`;
* список пользователей задаётся явно;
* не используется автоматическое добавление всех пользователей;
* учитывается риск повышения привилегий через Docker.

---

## 🚫 Что не входит в роль

* настройка registry;
* настройка docker daemon.json;
* настройка rootless Docker;
* установка Kubernetes;
* настройка сетей и volume;
* установка docker-compose как standalone binary.

---

## 📌 Ограничения текущей версии

* Astra Linux не поддерживает актуальную версию Docker;
* отсутствует унификация версий между платформами.
