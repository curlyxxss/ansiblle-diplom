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

## Что делает роль

Роль выполняет:

- проверку наличия `sshd_config`;
- запрет входа root по SSH;
- запрет парольной SSH-аутентификации;
- включение входа по публичному ключу;
- ограничение SSH-доступа через `AllowUsers`;
- настройку лимитов SSH-аутентификации;
- дополнительный SSH hardening;
- установку и настройку fail2ban;
- установку и настройку ufw;
- применение базовых sysctl-параметров.

---

## Поддерживаемые платформы

- Ubuntu 24.04
- Astra Linux Orel

Для Astra Linux часть задач выполняется отдельной веткой, так как поведение пакетов и сервисов может отличаться от Ubuntu.

---

## Структура роли

```text
roles/security/
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
├── tasks/
│   ├── fail2ban.yml
│   ├── firewall.yml
│   ├── main.yml
│   ├── ssh.yml
│   └── sysctl.yml
└── README.md
```

---

## SSH hardening

Роль настраивает SSH как основной канал администрирования рабочей станции.

### Базовые настройки

Реализовано:

- `PermitRootLogin no`
- `PasswordAuthentication no`
- `PubkeyAuthentication yes`
- `AllowUsers`
- `MaxAuthTries`
- `LoginGraceTime`
- `ClientAliveInterval`
- `ClientAliveCountMax`

### Security v3

В версии `security v3` добавлены дополнительные параметры SSH:

- `PermitEmptyPasswords no`
- `X11Forwarding no`
- `AllowTcpForwarding no`
- `MaxSessions`
- `MaxStartups`

Эти настройки уменьшают поверхность атаки SSH-сервиса и ограничивают лишние возможности удалённого подключения.

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

## Fail2ban

Роль устанавливает и включает `fail2ban`.

Fail2ban используется для защиты SSH от brute-force атак.

Роль создаёт локальный jail для `sshd` и включает сервис.

Проверка:

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

Ожидаемо:

```text
Jail list: sshd
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

В версии `security v3` добавлены базовые сетевые sysctl-настройки.

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

### Путь к SSH-конфигурации

```yaml
security_sshd_config_path: /etc/ssh/sshd_config
```

---

### Разрешённые SSH-пользователи

```yaml
security_ssh_allow_users:
  - ansible
  - developer
```

Эти пользователи будут записаны в `AllowUsers`.

Важно: если пользователь не указан в `security_ssh_allow_users`, он не сможет подключиться по SSH.

---

### Базовые SSH-настройки

```yaml
security_ssh_permit_root_login: "no"
security_ssh_password_authentication: "no"
security_ssh_pubkey_authentication: "yes"

security_ssh_max_auth_tries: 3
security_ssh_login_grace_time: "30s"
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

### Fail2ban

```yaml
security_fail2ban_enabled: true

security_fail2ban_jail_name: sshd
security_fail2ban_bantime: 600
security_fail2ban_findtime: 600
security_fail2ban_maxretry: 5
```

---

### Firewall

```yaml
security_firewall_enabled: true

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

Если SSH работает на нестандартном порту, его нужно явно разрешить:

```yaml
security_firewall_allowed_ports:
  - 2222
```

---

## Важное предупреждение про SSH-доступ

Роль изменяет SSH-конфигурацию.

Перед запуском необходимо убедиться, что:

- пользователь `ansible` существует;
- у пользователя `ansible` есть SSH-ключ;
- пользователь `ansible` добавлен в `security_ssh_allow_users`;
- sudo-доступ работает;
- firewall разрешает текущий SSH-порт.

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

---

## force_handlers

Для playbook'а `security.yml` рекомендуется использовать:

```yaml
force_handlers: true
```

Пример:

```yaml
- name: Apply security configuration
  hosts: workstations
  become: true
  gather_facts: true
  force_handlers: true

  roles:
    - security
```

Причина: роль изменяет SSH-конфигурацию. Если playbook изменил `sshd_config`, но затем упал на другом хосте, handler перезапуска SSH всё равно должен выполниться.

Иначе возможна ситуация:

```text
sshd_config изменён, но sshd продолжает работать со старой конфигурацией
```

---

## Проверка после применения роли

### SSH

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

## Идемпотентность

Роль проверена повторным запуском.

Ожидаемый результат при повторном применении:

```text
changed=0
failed=0
unreachable=0
```

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
- rootless Docker security.

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
- ограничивает пользователей;
- включает fail2ban;
- включает firewall;
- применяет базовые sysctl-настройки;
- сохраняет управляемость через Ansible.

Роль является одним из ключевых компонентов проекта, так как именно она обеспечивает защищённость подготовленной рабочей станции.