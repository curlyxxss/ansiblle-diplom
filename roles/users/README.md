# Role: users

## Назначение

Роль users управляет учетными записями пользователей на рабочих станциях.

Роль предназначена для централизованного управления доступом и обеспечивает:

* создание пользователей;
* настройку shell;
* назначение групп;
* установку SSH-ключей;
* управление sudo-доступом.

---

## Что делает роль

* создаёт пользователей;
* создаёт домашние каталоги;
* создаёт каталог .ssh;
* добавляет SSH-ключи в authorized_keys;
* управляет sudo-правами через /etc/sudoers.d;
* поддерживает состояния present и absent.

---

## Что не входит в роль

Роль users не выполняет:

* bootstrap начального SSH-доступа;
* настройку SSH-сервера;
* настройку парольной политики;
* автоматическое удаление всех неуправляемых пользователей;
* безопасное хранение SSH-ключей.

---

## Поддерживаемые платформы

* Ubuntu 24.04
* Astra Linux Orel

---

## Принцип работы

Роль реализует модель:

* код роли содержит логику;
* inventory/group_vars содержит реальные пользовательские данные.

Это позволяет централизованно управлять учетными записями без изменения самой роли.

---

## Основные переменные

Определяются в defaults/main.yml.

### users_manage_accounts

Включает или отключает управление учетными записями.

users_manage_accounts: true

### users_default_shell

Shell по умолчанию для пользователей.

users_default_shell: /bin/bash

### users_default_groups

Группы по умолчанию.

users_default_groups: []

### users

Список управляемых пользователей. По умолчанию пустой и должен задаваться в inventory.

Пример:

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

  - name: developer
    state: present
    shell: /bin/bash
    groups: []
    ssh_keys:
      - "files/ssh_keys/developer.pub"
    sudo: false
    sudo_nopasswd: false

---

## Рекомендуемое размещение пользовательских данных

inventories/group_vars/workstations.yml

---

## Пример использования

- name: Manage workstation users
  hosts: workstations
  become: true

  roles:
    - users

---

## Особенности реализации

* sudo настраивается через отдельные файлы в /etc/sudoers.d;
* синтаксис sudoers проверяется через visudo;
* SSH-ключи добавляются через authorized_key;
* роль рассчитана на масштабирование до нескольких пользователей.

---

## Ограничения текущей версии

* не удаляет автоматически пользователей, отсутствующих в конфигурации;
* не управляет паролями;
* не управляет сроком действия учетных записей;
* не реализует сложную ролевую модель пользователей.
## Users v2

Роль `users` поддерживает расширенную модель управления учетными записями.

### Что добавлено

- `comment` — описание пользователя;
- `password_lock` — блокировка парольного входа;
- `state: absent` — явное удаление пользователя;
- `remove_home` — управление удалением домашнего каталога при удалении пользователя;
- управление sudo-доступом через `/etc/sudoers.d`;
- удаление sudoers-файла у пользователей без sudo-доступа.

Роль не удаляет пользователей, которые не описаны в переменной `users`. Это сделано намеренно, чтобы избежать случайного удаления системных или локальных учетных записей.

---

## Модель пользователей

Рекомендуемая модель для проекта:

```text
ansible   -> служебный пользователь автоматизации
developer -> пользователь-разработчик
```

### Пользователь `ansible`

Используется только для Ansible:

- подключение по SSH;
- выполнение playbook'ов;
- `sudo`;
- `NOPASSWD`;
- парольный вход заблокирован.

### Пользователь `developer`

Используется для ежедневной работы:

- SSH-доступ по ключу;
- dev-инструменты;
- Docker-доступ через отдельную роль;
- без sudo-доступа по умолчанию.

---

## Пример конфигурации

```yaml
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
```

---

## Удаление пользователя

Пользователь удаляется только если явно указан:

```yaml
users:
  - name: setup
    state: absent
    remove_home: false
```

Если нужно удалить домашний каталог пользователя:

```yaml
users:
  - name: setup
    state: absent
    remove_home: true
```

По умолчанию домашний каталог не удаляется:

```yaml
users_absent_remove_home: false
```

Это снижает риск случайной потери пользовательских данных.

---

## Блокировка пароля

Для пользователей, которые входят только по SSH-ключу, рекомендуется использовать:

```yaml
password_lock: true
```

Это блокирует парольный вход, но не мешает SSH-доступу по ключу.

Рекомендуется для:

```yaml
ansible:
  password_lock: true

developer:
  password_lock: true
```

Если пользователю нужен локальный вход по паролю через GUI или консоль, `password_lock` можно отключить, но тогда пароль должен задаваться отдельно и безопасно, например через Ansible Vault.

---

## Важное замечание про идемпотентность

Если указать:

```yaml
password_lock: false
```

для пользователя, у которого фактически нет заданного пароля, Ansible может пытаться разблокировать пароль при каждом запуске. Это может приводить к повторяющемуся `changed`.

Для SSH-only пользователей лучше использовать:

```yaml
password_lock: true
```

---

## Проверка

Проверить пользователей:

```bash
ansible all -m command -a "getent passwd ansible"
ansible all -m command -a "getent passwd developer"
```

Проверить состояние пароля:

```bash
ansible all -m command -a "passwd -S ansible" -b
ansible all -m command -a "passwd -S developer" -b
```

Ожидаемый статус при `password_lock: true`:

```text
L
```

Проверить sudo-доступ:

```bash
ansible all -m command -a "sudo -l -U ansible" -b
ansible all -m command -a "sudo -l -U developer" -b
```

Пользователь `ansible` должен иметь sudo-доступ, а `developer` — не иметь его по умолчанию.