# Role: users

## Назначение

Роль `users` управляет учетными записями пользователей на рабочих станциях.

Роль предназначена для централизованного управления доступом после первичного bootstrap-этапа и обеспечивает:

- создание управляемых пользователей;
- настройку shell и comment;
- настройку SSH-ключей;
- управление sudo-доступом;
- блокировку парольного входа;
- явное удаление пользователей через `state: absent`;
- безопасное управление удалением home directory через `remove_home`;
- отсутствие автоматического удаления неописанных пользователей.

---

## Место роли в общем пайплайне

Роль `users` запускается после роли `base`.

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

- создаёт пользователей;
- создаёт домашние каталоги;
- задаёт shell пользователя;
- задаёт comment пользователя;
- создаёт каталог `.ssh`;
- добавляет SSH-ключи в `authorized_keys`;
- управляет sudo-правами через `/etc/sudoers.d`;
- проверяет sudoers-файлы через `visudo`;
- поддерживает состояния `present` и `absent`;
- блокирует пароль пользователя при необходимости;
- удаляет sudoers-файл у пользователей без sudo-доступа.

---

## Что не входит в роль

Роль `users` не выполняет:

- bootstrap начального SSH-доступа;
- установку пакета `sudo`;
- настройку SSH-сервера;
- настройку парольной политики;
- автоматическое удаление всех неуправляемых пользователей;
- безопасное хранение SSH-ключей;
- установку Docker;
- установку инструментов разработки.

Эти задачи вынесены в другие этапы и роли.

---

## Поддерживаемые платформы

На текущем этапе роль поддерживает:

- Ubuntu 24.04;
- Debian 12.13.0;
- Astra Linux Orel 2.12.


---

## Требования

Для корректной работы роли на целевой машине должны быть доступны:

- SSH-доступ под пользователем Ansible;
- возможность выполнять команды через `become: true`;
- установленный пакет `sudo`, если роль управляет sudo-доступом;
- директория `/etc/sudoers.d`;
- утилита `visudo`;
- публичные SSH-ключи на управляющей машине.

Для Debian 12.13.0 особенно важно, чтобы пакет `sudo` был установлен заранее. Обычно это выполняется на bootstrap-этапе или при подготовке машины.

Проверить наличие `visudo` можно командой:

```bash
ansible debian -m command -a "which visudo" -b
```

Ожидаемый результат:

```text
/usr/sbin/visudo
```

---

## Принцип работы

Роль реализует модель:

- код роли содержит только логику;
- `inventory`, `group_vars` и `host_vars` содержат реальные пользовательские данные.

Это позволяет централизованно управлять учетными записями без изменения самой роли.

---

## Основные переменные

Переменные определяются в:

```text
defaults/main.yml
```

---

### `users_manage_accounts`

Включает или отключает управление учетными записями.

Пример:

```yaml
users_manage_accounts: true
```

---

### `users_default_shell`

Shell по умолчанию для пользователей.

Пример:

```yaml
users_default_shell: /bin/bash
```

---

### `users_default_groups`

Группы по умолчанию.

Пример:

```yaml
users_default_groups: []
```

---

### `users_home_base`

Базовая директория для домашних каталогов пользователей.

Пример:

```yaml
users_home_base: /home
```

По умолчанию домашний каталог пользователя формируется так:

```text
/home/<username>
```

---

### `users`

Список управляемых пользователей.

По умолчанию список пустой и должен задаваться в `inventory`, `group_vars` или `host_vars`.

Пример:

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

### `users_remove_unmanaged`

Защитная переменная.

Роль не удаляет пользователей, которые не описаны в переменной `users`.

```yaml
users_remove_unmanaged: false
```

На текущем этапе автоматическое удаление неуправляемых пользователей не применяется намеренно, чтобы избежать случайного удаления системных или локальных учетных записей.

---

### `users_absent_remove_home`

Поведение по умолчанию при удалении пользователя.

```yaml
users_absent_remove_home: false
```

Если значение `false`, пользователь удаляется без удаления домашнего каталога.

Если значение `true`, домашний каталог пользователя удаляется вместе с учетной записью.

---

### `users_sudoers_validate_path`

Путь к `visudo`, используемый для проверки sudoers-файлов.

Пример:

```yaml
users_sudoers_validate_path: /usr/sbin/visudo
```

Для Ubuntu, Debian и Astra Linux обычно используется путь:

```text
/usr/sbin/visudo
```

---

## Рекомендуемое размещение пользовательских данных

Пользовательские данные рекомендуется хранить на уровне inventory.

Пример:

```text
inventories/group_vars/workstations.yml
```

Или точечно для конкретной ОС:

```text
inventories/group_vars/ubuntu_hosts.yml
inventories/group_vars/debian_hosts.yml
inventories/group_vars/astra_hosts.yml
```

Если пользователи одинаковые для всех рабочих станций, достаточно `group_vars/workstations.yml`.

---

## Модель пользователей

Рекомендуемая модель для проекта:

```text
ansible   -> служебный пользователь автоматизации
developer -> пользователь-разработчик
```

---

### Пользователь `ansible`

Используется только для Ansible:

- подключение по SSH;
- выполнение playbook'ов;
- выполнение задач с `become: true`;
- наличие sudo-доступа;
- `NOPASSWD`;
- парольный вход заблокирован.

Пример:

```yaml
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
```

---

### Пользователь `developer`

Используется для ежедневной работы:

- SSH-доступ по ключу;
- работа с dev-инструментами;
- Docker-доступ через отдельную роль;
- без sudo-доступа по умолчанию;
- парольный вход может быть заблокирован, если используется только SSH-ключ.

Пример:

```yaml
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

## Особенности sudo-доступа

Sudo-доступ настраивается через отдельные файлы:

```text
/etc/sudoers.d/<username>
```

Для пользователя с `sudo: true` и `sudo_nopasswd: true` создается файл следующего вида:

```text
ansible ALL=(ALL) NOPASSWD:ALL
```

Для пользователя с `sudo: true` и `sudo_nopasswd: false` создается правило:

```text
developer ALL=(ALL) ALL
```

Если у пользователя указано:

```yaml
sudo: false
```

роль удаляет его sudoers-файл, если он был создан ранее.

---

## Важное замечание для Debian

На Debian 12.13.0 роль работает без отдельного `debian.yml`, но есть несколько условий:

- пакет `sudo` должен быть установлен;
- пользователь `ansible` должен иметь возможность выполнять `become: true`;
- файл `/etc/sudoers.d/<username>` должен проверяться через `visudo`;
- если пользователь добавляется в группу `sudo`, новая групповая сессия может примениться только после повторного входа пользователя в систему.

Если после добавления пользователя в группу `sudo` команда `groups` не показывает новую группу, нужно выйти из сессии и войти заново. В некоторых случаях помогает перезагрузка машины.

---

## Блокировка пароля

Для пользователей, которые входят только по SSH-ключу, рекомендуется использовать:

```yaml
password_lock: true
```

Это блокирует парольный вход, но не мешает SSH-доступу по ключу.

Рекомендуется для:

```yaml
users:
  - name: ansible
    password_lock: true

  - name: developer
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
- name: Manage workstation users
  hosts: workstations
  become: true

  roles:
    - users
```

---

## Запуск роли

Запуск для всех рабочих станций:

```bash
ansible-playbook playbooks/users.yml
```

Запуск только для Debian:

```bash
ansible-playbook playbooks/users.yml --limit debian
```

Если в inventory используется группа `debian_hosts`, можно запустить так:

```bash
ansible-playbook playbooks/users.yml --limit debian_hosts
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

Пользователь `ansible` должен иметь sudo-доступ.

Пользователь `developer` по умолчанию не должен иметь sudo-доступ.

---

## Проверка SSH-ключей

Проверить наличие директории `.ssh`:

```bash
ansible all -m command -a "ls -ld /home/ansible/.ssh" -b
ansible all -m command -a "ls -ld /home/developer/.ssh" -b
```

Проверить наличие `authorized_keys`:

```bash
ansible all -m command -a "ls -l /home/ansible/.ssh/authorized_keys" -b
ansible all -m command -a "ls -l /home/developer/.ssh/authorized_keys" -b
```

Ожидаемые права:

```text
/home/<user>/.ssh                 700
/home/<user>/.ssh/authorized_keys 600
```

---

## Особенности реализации

- пользователи управляются через `ansible.builtin.user`;
- SSH-ключи добавляются через `ansible.posix.authorized_key`;
- sudo настраивается через отдельные файлы в `/etc/sudoers.d`;
- синтаксис sudoers проверяется через `visudo`;
- роль рассчитана на масштабирование до нескольких пользователей;
- роль не удаляет пользователей, которые не описаны в переменной `users`.

---

## Ограничения текущей версии

- роль не удаляет автоматически пользователей, отсутствующих в конфигурации;
- роль не управляет паролями;
- роль не управляет сроком действия учетных записей;
- роль не реализует сложную ролевую модель пользователей;
- роль не устанавливает пакет `sudo`;
- роль не управляет настройками SSH-сервера.

---

## Итог

Роль `users` отвечает за централизованное управление учетными записями на рабочих станциях.

После выполнения роли система получает:

- управляемого служебного пользователя `ansible`;
- управляемого пользователя-разработчика;
- настроенные SSH-ключи;
- контролируемый sudo-доступ;
- заблокированный парольный вход для SSH-only пользователей;
- безопасную модель удаления пользователей только через явное `state: absent`.
