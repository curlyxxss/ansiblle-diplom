# Role: security

## Назначение

Роль security реализует базовую многоуровневую защиту рабочих станций.

Роль предназначена для:

* усиления безопасности SSH;
* защиты от brute-force атак;
* ограничения сетевого доступа;
* формирования базового security baseline корпоративной рабочей станции.

---

## Что делает роль

### SSH hardening

* запрещает SSH-вход под root;
* отключает аутентификацию по паролю;
* разрешает только вход по SSH-ключам;
* ограничивает список допустимых пользователей (AllowUsers);
* ограничивает число попыток входа (MaxAuthTries);
* ограничивает время аутентификации (LoginGraceTime);
* управляет поведением SSH-сессий (ClientAliveInterval, ClientAliveCountMax);
* проверяет конфигурацию через sshd -t.

### Fail2ban

* устанавливает fail2ban;
* создаёт jail.local;
* включает jail для sshd;
* запускает и включает сервис.

### Firewall

* устанавливает ufw;
* разрешает только явно указанные порты;
* устанавливает политику:

  * deny incoming
  * allow outgoing
* включает firewall.

---

## Что не входит в роль

Роль security не выполняет:

* настройку расширенного аудита;
* централизованный сбор логов;
* сложные политики firewall;
* ограничение доступа по IP;
* интеграцию с SIEM/IDS/IPS;
* продвинутые enterprise-механизмы защиты.

---

## Поддерживаемые платформы

* Ubuntu 24.04
* Astra Linux Orel

---

## Основные переменные

Определяются в defaults/main.yml.

### SSH

security_ssh_permit_root_login: "no"
security_ssh_password_authentication: "no"
security_ssh_pubkey_authentication: "yes"

security_ssh_allow_users:
  - devuser

security_ssh_max_auth_tries: 3
security_ssh_login_grace_time: 30
security_ssh_client_alive_interval: 300
security_ssh_client_alive_count_max: 2

### Fail2ban

security_fail2ban_enabled: true
security_fail2ban_maxretry: 5
security_fail2ban_bantime: 600

### Firewall

security_firewall_enabled: true
security_firewall_allowed_ports:
  - 22

---

## Структура задач

tasks/
├── main.yml
├── ssh.yml
├── fail2ban.yml
└── firewall.yml

* ssh.yml — SSH hardening;
* fail2ban.yml — защита от brute-force;
* firewall.yml — firewall policy;
* main.yml — маршрутизация выполнения.

---

## Пример использования

- name: Apply security configuration
  hosts: workstations
  become: true

  roles:
    - security

---

## Особенности реализации

* изменения в sshd_config валидируются через sshd -t;
* перезапуск SSH выполняется только при изменениях через handlers;
* на Astra Linux установка части пакетов выполняется через raw;
* firewall реализован через ufw как безопасный и управляемый baseline.

---

## Ограничения текущей версии

* не настраивает аудит действий пользователей;
* не реализует расширенные правила firewall;
* не ограничивает доступ по IP;
* не интегрируется с корпоративными системами мониторинга;
* не включает продвинутые security-политики уровня enterprise.
