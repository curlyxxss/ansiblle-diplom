# Role: security

## Назначение

Роль `security` применяет базовый security baseline для рабочей станции разработчика.

Роль отвечает за:

- усиление SSH-конфигурации;
- ограничение удалённого доступа;
- защиту от brute-force атак;
- настройку firewall;
- применение базовых сетевых sysctl-настроек.

Роль предназначена для запуска после базовой настройки ОС и создания пользователей.

Рекомендуемый порядок:

```text
base -> users -> security -> docker -> dev
```

---

## Место роли в общем пайплайне

Роль `security` запускается после ролей `base` и `users`.

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

- проверяет наличие `sshd_config`;
- запрещает вход root по SSH;
- запрещает парольную SSH-аутентификацию;
- включает вход по публичному ключу;
- при необходимости ограничивает SSH-доступ через `AllowUsers`;
- настраивает лимиты SSH-аутентификации;
- применяет дополнительный SSH hardening;
- очищает дублирующиеся директивы `X11Forwarding`;
- устанавливает и настраивает `fail2ban`;
- устанавливает и настраивает `ufw`;
- применяет базовые sysctl-параметры.

---

## Что не входит в роль

Роль `security` не выполняет:

- создание пользователей;
- первичный bootstrap SSH-доступа;
- установку SSH-ключей;
- управление пользовательскими паролями;
- настройку Docker;
- установку dev-инструментов;
- настройку VPN;
- централизованный сбор логов;
- полную настройку auditd/SIEM;
- управление встроенными режимами защиты Astra Linux.

Эти задачи вынесены в другие роли или могут быть реализованы в следующих версиях проекта.

---

## Поддерживаемые платформы

На текущем этапе роль поддерживает:

- Ubuntu 24.04;
- Debian 12.13.0;
- Astra Linux Orel 2.12.

Для Ubuntu и Debian используются стандартные Ansible-модули и пакетный менеджер `apt`.

Для Astra Linux часть задач выполняется отдельной веткой, так как поведение пакетов, Python-интерпретатора и сервисов может отличаться от Ubuntu/Debian.

---

## Требования

Для корректной работы роли на целевой машине должны быть доступны:

- SSH-доступ под пользователем Ansible;
- возможность выполнять команды через `become: true`;
- установленный и работающий OpenSSH server;
- пользователь `ansible` или другой управляющий пользователь с sudo-доступом;
- рабочие репозитории пакетов;
- доступные пакеты `fail2ban` и `ufw`, если соответствующие функции включены;
- утилита проверки конфигурации SSH-сервера.

Для Ubuntu, Debian и Astra Linux обычно используется путь:

```text
/usr/sbin/sshd
```

Для проверки sudoers-файлов в других ролях обычно используется:

```text
/usr/sbin/visudo
```

---

## Структура роли

```text
roles/security/
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── ssh.yml
│   ├── fail2ban.yml
│   ├── firewall.yml
│   └── sysctl.yml
└── README.md
```

Назначение файлов:

- `defaults/main.yml` — переменные по умолчанию;
- `handlers/main.yml` — перезапуск сервисов после изменения конфигурации;
- `tasks/main.yml` — подключение частей роли;
- `tasks/ssh.yml` — SSH hardening;
- `tasks/fail2ban.yml` — установка и настройка fail2ban;
- `tasks/firewall.yml` — установка и настройка ufw;
- `tasks/sysctl.yml` — сетевые sysctl-настройки.

---

## SSH hardening

Роль настраивает SSH как основной канал администрирования рабочей станции.

### Базовые настройки

Реализовано:

- `PermitRootLogin no`;
- `PasswordAuthentication no`;
- `PubkeyAuthentication yes`;
- `MaxAuthTries`;
- `LoginGraceTime`;
- `ClientAliveInterval`;
- `ClientAliveCountMax`.

Ограничение через `AllowUsers` применяется только если список пользователей явно задан в переменной `security_ssh_allow_users`.

---

### Дополнительный hardening

В роли также настраиваются параметры:

- `PermitEmptyPasswords no`;
- `X11Forwarding no`;
- `AllowTcpForwarding no`;
- `MaxSessions`;
- `MaxStartups`.

Эти настройки уменьшают поверхность атаки SSH-сервиса и ограничивают лишние возможности удалённого подключения.

---

## Валидация SSH-конфигурации

В роли используются два разных типа проверки SSH-конфигурации.

### Проверка временного файла Ansible

Модули `lineinfile`, `copy` и похожие модули используют параметр `validate`.

Для него нужна команда с `%s`, потому что Ansible подставляет туда путь к временному файлу:

```yaml
security_sshd_validate_file_command: "/usr/sbin/sshd -t -f %s"
```

Эта переменная используется только внутри параметра:

```yaml
validate: "{{ security_sshd_validate_file_command }}"
```

---

### Финальная проверка живого конфига

Для отдельной задачи проверки после всех изменений используется команда без `%s`.

Пример переменной:

```yaml
security_sshd_validate_live_argv:
  - /usr/sbin/sshd
  - -t
  - -f
  - "{{ security_sshd_config_path }}"
```

Эта переменная используется в задаче:

```yaml
- name: Validate sshd configuration
  ansible.builtin.command:
    argv: "{{ security_sshd_validate_live_argv }}"
  changed_when: false
```

Важно: нельзя использовать команду с `%s` в обычной задаче `command`, потому что `%s` там не подставляется и будет воспринят как буквальное имя файла.

---

## AllowUsers

Переменная `security_ssh_allow_users` управляет директивой SSH:

```text
AllowUsers
```

По умолчанию список должен быть пустым:

```yaml
security_ssh_allow_users: []
```

Пустой список означает:

```text
роль не прописывает AllowUsers и не ограничивает SSH-доступ через эту директиву
```

Это безопасное значение по умолчанию, потому что роль не должна случайно заблокировать доступ к машине.

Если нужно явно ограничить SSH-доступ, список задаётся в `group_vars` или `host_vars`.

Пример:

```yaml
security_ssh_allow_users:
  - ansible
  - developer
```

В этом случае в SSH-конфигурацию будет добавлена строка:

```text
AllowUsers ansible developer
```

Важно: если пользователь не указан в `security_ssh_allow_users`, он не сможет подключиться по SSH после применения роли.

---

## Важное предупреждение про SSH-доступ

Роль изменяет SSH-конфигурацию.

Перед запуском необходимо убедиться, что:

- пользователь `ansible` существует;
- у пользователя `ansible` есть SSH-ключ;
- пользователь `ansible` имеет sudo-доступ;
- `become: true` работает;
- firewall разрешает текущий SSH-порт;
- если используется `AllowUsers`, пользователь `ansible` добавлен в `security_ssh_allow_users`.

Рекомендуется проверка перед запуском:

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

Если `security_ssh_allow_users` пустой, роль должна удалить ранее созданную строку `AllowUsers` или не создавать её.

---

## X11Forwarding

На некоторых системах в `/etc/ssh/sshd_config` может быть несколько директив:

```text
X11Forwarding yes
X11Forwarding no
```

Из-за этого Ansible может показывать повторный `changed` или SSH может применять неочевидное значение.

Роль должна приводить конфигурацию к одному управляемому состоянию:

```text
X11Forwarding no
```

Для этого используется логика:

- подсчитать количество директив `X11Forwarding`;
- если их больше одной, удалить дубли;
- затем выставить одну правильную строку.

На первом запуске эта часть может показать `changed`, если роль очищает старые дубли. На повторном запуске блок должен становиться идемпотентным.

---

## Важное замечание про AllowTcpForwarding

По умолчанию рекомендуется отключать TCP forwarding:

```text
AllowTcpForwarding no
```

Это повышает безопасность, так как запрещает SSH-туннели.

Однако в некоторых сценариях разработчики могут использовать SSH port forwarding для:

- подключения к базам данных;
- remote development;
- временных туннелей;
- доступа к внутренним сервисам.

Если SSH-туннели необходимы, параметр можно изменить через переменную:

```yaml
security_ssh_allow_tcp_forwarding: "yes"
```

---

## Drop-in конфигурация SSH

На Ubuntu и Debian может использоваться директория:

```text
/etc/ssh/sshd_config.d
```

Файлы в этой директории могут переопределять параметры из основного файла:

```text
/etc/ssh/sshd_config
```

Поэтому роль может создавать отдельный управляемый drop-in файл:

```text
/etc/ssh/sshd_config.d/00-ansible-security.conf
```

Управляется переменными:

```yaml
security_sshd_manage_dropin: true
security_sshd_config_dropin_dir: /etc/ssh/sshd_config.d
security_sshd_security_dropin_path: /etc/ssh/sshd_config.d/00-ansible-security.conf
```

Если директория отсутствует, задача создания drop-in файла пропускается.

---

## Fail2ban

Роль устанавливает и включает `fail2ban`.

Fail2ban используется для защиты SSH от brute-force атак.

Роль создаёт локальный jail для `sshd` и включает сервис.

Для Ubuntu и Debian установка выполняется через `ansible.builtin.apt`.

Для Astra Linux установка может выполняться через отдельную ветку совместимости.

Проверка:

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

Ожидаемо:

```text
Jail list: sshd
```

На некоторых системах задача включения и запуска сервиса может показывать `changed` при повторном запуске, даже если сервис уже находится в состоянии `active` и `enabled`. Если проверки ниже успешны, это не влияет на функциональность роли:

```bash
systemctl is-active fail2ban
systemctl is-enabled fail2ban
```

Ожидаемо:

```text
active
enabled
```

---

## Firewall

Роль устанавливает и включает `ufw`.

Используемая политика:

- входящие соединения запрещены по умолчанию;
- исходящие соединения разрешены по умолчанию;
- открываются только явно указанные порты.

По умолчанию разрешается SSH-порт:

```yaml
security_firewall_allowed_ports:
  - 22
```

Для Ubuntu и Debian установка выполняется через `ansible.builtin.apt`.

Для Astra Linux установка может выполняться через отдельную ветку совместимости.

Проверка:

```bash
sudo ufw status verbose
```

Ожидаемо:

```text
Status: active
Default: deny (incoming), allow (outgoing)
```

---

## Sysctl hardening

Добавлены базовые сетевые sysctl-настройки.

Они записываются в файл:

```text
/etc/sysctl.d/99-workstation-security.conf
```

Роль управляет параметрами:

```yaml
security_sysctl_settings:
  net.ipv4.conf.all.accept_redirects: "0"
  net.ipv4.conf.default.accept_redirects: "0"
  net.ipv4.conf.all.send_redirects: "0"
  net.ipv4.conf.default.send_redirects: "0"
  net.ipv4.conf.all.accept_source_route: "0"
  net.ipv4.conf.default.accept_source_route: "0"
  net.ipv4.icmp_echo_ignore_broadcasts: "1"
  net.ipv4.tcp_syncookies: "1"
```

Назначение:

- запрет ICMP redirects;
- запрет source routing;
- отключение отправки redirects;
- защита от broadcast ICMP;
- включение TCP SYN cookies.

Проверка:

```bash
sysctl net.ipv4.tcp_syncookies
sysctl net.ipv4.conf.all.accept_redirects
cat /etc/sysctl.d/99-workstation-security.conf
```

---

## Основные переменные

Переменные определяются в:

```text
defaults/main.yml
```

---

### Управление SSH

```yaml
security_ssh_port: 22

security_ssh_permit_root_login: "no"
security_ssh_password_authentication: "no"
security_ssh_pubkey_authentication: "yes"

security_sshd_config_path: /etc/ssh/sshd_config
security_sshd_validate_file_command: "/usr/sbin/sshd -t -f %s"

security_sshd_validate_live_argv:
  - /usr/sbin/sshd
  - -t
  - -f
  - "{{ security_sshd_config_path }}"
```

---

### Разрешённые SSH-пользователи

```yaml
security_ssh_allow_users: []
```

Пустой список означает, что роль не будет ограничивать SSH-доступ через `AllowUsers`.

Пример ограничения доступа:

```yaml
security_ssh_allow_users:
  - ansible
  - developer
```

---

### Базовые SSH-настройки

```yaml
security_ssh_max_auth_tries: 3
security_ssh_login_grace_time: 30
security_ssh_client_alive_interval: 300
security_ssh_client_alive_count_max: 2
```

---

### Дополнительный SSH hardening

```yaml
security_ssh_permit_empty_passwords: "no"
security_ssh_x11_forwarding: "no"
security_ssh_allow_tcp_forwarding: "no"
security_ssh_max_sessions: 2
security_ssh_max_startups: "10:30:60"
```

---

### Drop-in SSH config

```yaml
security_sshd_manage_dropin: true
security_sshd_config_dropin_dir: /etc/ssh/sshd_config.d
security_sshd_security_dropin_path: /etc/ssh/sshd_config.d/00-ansible-security.conf
```

---

### Fail2ban

```yaml
security_fail2ban_enabled: true
security_fail2ban_package: fail2ban
security_fail2ban_service: fail2ban
security_fail2ban_maxretry: 5
security_fail2ban_bantime: 600
security_fail2ban_backend: auto
security_fail2ban_sshd_logpath: /var/log/auth.log
```

---

### Firewall

```yaml
security_firewall_enabled: true
security_firewall_package: ufw

security_firewall_allowed_ports:
  - 22
```

---

### Sysctl

```yaml
security_sysctl_enabled: true
```

---

## Пример конфигурации

Пример `inventories/group_vars/workstations.yml`:

```yaml
security_ssh_allow_users:
  - ansible
  - developer

security_firewall_allowed_ports:
  - 22

security_ssh_allow_tcp_forwarding: "no"

security_sysctl_enabled: true
```

Если не нужно ограничивать SSH через `AllowUsers`, оставь список пустым:

```yaml
security_ssh_allow_users: []
```

Если SSH работает на нестандартном порту, его нужно явно разрешить:

```yaml
security_firewall_allowed_ports:
  - 2222
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
- name: Apply security configuration
  hosts: workstations
  become: true
  gather_facts: true
  force_handlers: true

  roles:
    - security
```

---

## Запуск роли

Запуск для всех рабочих станций:

```bash
ansible-playbook playbooks/security.yml
```

Запуск только для Debian:

```bash
ansible-playbook playbooks/security.yml --limit debian
```

Если в inventory используется группа `debian_hosts`, можно запустить так:

```bash
ansible-playbook playbooks/security.yml --limit debian_hosts
```

---

## force_handlers

Для playbook'а `security.yml` рекомендуется использовать:

```yaml
force_handlers: true
```

Причина: роль изменяет SSH-конфигурацию. Если playbook изменил `sshd_config`, но затем упал на другом хосте, handler перезапуска SSH всё равно должен выполниться.

Иначе возможна ситуация:

```text
sshd_config изменён, но sshd продолжает работать со старой конфигурацией
```

---

## Проверка после применения роли

### SSH

Проверить основные параметры:

```bash
sudo sshd -T | grep -Ei "permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers"
```

Дополнительный hardening:

```bash
sudo sshd -T | grep -Ei "permitemptypasswords|x11forwarding|allowtcpforwarding|maxsessions|maxstartups"
```

Ожидаемые значения:

```text
permitrootlogin no
passwordauthentication no
pubkeyauthentication yes
permitemptypasswords no
x11forwarding no
allowtcpforwarding no
maxsessions 2
maxstartups 10:30:60
```

Если `security_ssh_allow_users: []`, параметр `allowusers` в выводе может отсутствовать. Это нормальное поведение.

---

### Проверка конфигурации SSH

На Ubuntu/Debian:

```bash
sudo /usr/sbin/sshd -t -f /etc/ssh/sshd_config
```

Или через Ansible:

```bash
ansible all -m command -a "/usr/sbin/sshd -t -f /etc/ssh/sshd_config" -b
```

Команда не должна вернуть ошибку.

---

### Проверка X11Forwarding

Проверить строки в основном конфиге:

```bash
sudo grep -RniE '^\s*#?\s*X11Forwarding' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null
```

После применения роли не должно быть конфликтующих активных значений `yes` и `no`.

Проверить фактическое значение, которое видит SSH daemon:

```bash
sudo sshd -T | grep x11forwarding
```

Ожидаемо:

```text
x11forwarding no
```

---

### Fail2ban

```bash
sudo systemctl status fail2ban
sudo fail2ban-client status
```

---

### Firewall

```bash
sudo ufw status verbose
```

---

### Sysctl

```bash
sysctl net.ipv4.tcp_syncookies
sysctl net.ipv4.conf.all.accept_redirects
cat /etc/sysctl.d/99-workstation-security.conf
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

Проверить sudo и become:

```bash
ansible debian -m command -a "whoami" -b
```

Ожидаемый результат:

```text
root
```

Проверить наличие `sshd` и `visudo`:

```bash
ansible debian -m command -a "which sshd" -b
ansible debian -m command -a "which visudo" -b
```

Обычно ожидается:

```text
/usr/sbin/sshd
/usr/sbin/visudo
```

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

Однако некоторые задачи могут показывать `changed`, если системные сервисы или пакетный менеджер возвращают изменения состояния.

Допустимый пример:

- `Ensure fail2ban is enabled and started` может показывать `changed`, если сервис фактически остаётся `active` и `enabled`.

Проверка:

```bash
systemctl is-active fail2ban
systemctl is-enabled fail2ban
```

Если вывод:

```text
active
enabled
```

то повторный `changed` у этой задачи не влияет на функциональность.

Для SSH-блока повторный `changed` стоит проверять внимательнее, особенно если он связан с дублирующимися директивами в `sshd_config`.

---

## Ограничения

Роль не настраивает:

- auditd;
- SIEM-интеграцию;
- централизованный сбор логов;
- AppArmor/SELinux policies;
- встроенные режимы защиты Astra Linux;
- управление known_hosts;
- VPN;
- rootless Docker security;
- сложные профили hardening под разные классы пользователей.

Эти задачи могут быть реализованы в следующих версиях проекта.

---

## Замечание про предупреждения Ansible

При использовании модулей из коллекции `ansible.posix` может появляться предупреждение deprecation warning, связанное с совместимостью версии коллекции и `ansible-core`.

Рекомендуемое действие:

```bash
ansible-galaxy collection install ansible.posix --upgrade
```

Если предупреждение сохраняется, оно не является ошибкой роли и не влияет на применённые настройки.

---

## Итог

Роль `security` формирует базовый security baseline рабочей станции:

- защищает SSH;
- при необходимости ограничивает пользователей через `AllowUsers`;
- отключает X11 forwarding;
- отключает парольную SSH-аутентификацию;
- включает fail2ban;
- включает firewall;
- применяет базовые sysctl-настройки;
- сохраняет управляемость через Ansible.

Роль является одним из ключевых компонентов проекта, так как именно она обеспечивает защищённость подготовленной рабочей станции.
