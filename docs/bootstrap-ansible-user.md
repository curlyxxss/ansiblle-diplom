# Bootstrap Ansible User

## Назначение

Данный документ описывает использование скрипта:

```text
scripts/bootstrap-ansible-user.sh
```

Скрипт предназначен для первичной подготовки новой машины к управлению через Ansible.

Он создаёт служебного пользователя `ansible`, настраивает SSH-доступ по ключу и выдаёт права `sudo` без пароля для выполнения Ansible playbook'ов.

---

## Зачем нужен этот скрипт

Ansible не может управлять новой машиной, пока на ней нет пользователя, через которого можно подключиться по SSH и выполнить команды с повышенными правами.

Поэтому перед запуском Ansible требуется минимальный bootstrap-этап.

Скрипт решает именно эту задачу:

```text
чистая машина
    ↓
первичный доступ через setup/root/консоль
    ↓
bootstrap-ansible-user.sh
    ↓
пользователь ansible готов
    ↓
дальнейшая настройка через Ansible
```

---

## Что делает скрипт

Скрипт выполняет следующие действия:

- создаёт пользователя `ansible`;
- создаёт домашний каталог пользователя;
- создаёт директорию `/home/ansible/.ssh`;
- устанавливает публичный SSH-ключ в `authorized_keys`;
- выставляет корректные права доступа;
- добавляет пользователя в группу `sudo` или `wheel`;
- создаёт sudoers-файл:

```text
/etc/sudoers.d/ansible
```

- настраивает `NOPASSWD`;
- проверяет sudoers-файл через `visudo`;
- блокирует пароль пользователя.

---

## Что скрипт НЕ делает

Скрипт не выполняет полную настройку рабочей станции.

Он не устанавливает:

- базовые пакеты;
- Docker;
- dev-инструменты;
- firewall;
- fail2ban;
- Python dev-среду.

Эти задачи выполняются Ansible-ролями:

```text
base
users
security
docker
dev
```

---

## Требования

Для запуска скрипта на целевой машине требуется:

- локальный доступ к машине или временный пользователь;
- права `sudo`;
- установленный SSH server, если используется удалённый доступ;
- публичный SSH-ключ для пользователя `ansible`.

---

## Сценарий 1. Запуск через временного пользователя

На этапе установки ОС создаётся временный пользователь, например:

```text
setup
```

Далее с управляющей машины передаётся публичный ключ:

```bash
scp ~/.ssh/ansible.pub setup@<host>:/tmp/ansible.pub
```

Передаётся bootstrap-скрипт:

```bash
scp scripts/bootstrap-ansible-user.sh setup@<host>:/tmp/
```

Запуск на целевой машине:

```bash
ssh setup@<host>
sudo PUBLIC_KEY_FILE=/tmp/ansible.pub bash /tmp/bootstrap-ansible-user.sh
```

---

## Сценарий 2. Запуск через консоль машины

Если SSH ещё не настроен, скрипт можно запустить через локальную консоль виртуальной машины или физического устройства.

В этом случае публичный ключ можно заранее поместить в файл:

```bash
sudo PUBLIC_KEY_FILE=/tmp/ansible.pub bash bootstrap-ansible-user.sh
```

Либо, если скрипт поддерживает переменную `ANSIBLE_PUBLIC_KEY`, можно передать ключ напрямую:

```bash
sudo ANSIBLE_PUBLIC_KEY="ssh-ed25519 AAAA... ansible-key" bash bootstrap-ansible-user.sh
```

---

## Переменные окружения

Скрипт поддерживает настройку через переменные окружения.

### `ANSIBLE_USER`

Имя создаваемого служебного пользователя.

Значение по умолчанию:

```text
ansible
```

Пример:

```bash
sudo ANSIBLE_USER=automation PUBLIC_KEY_FILE=/tmp/ansible.pub bash bootstrap-ansible-user.sh
```

---

### `ANSIBLE_SHELL`

Shell для создаваемого пользователя.

Значение по умолчанию:

```text
/bin/bash
```

Пример:

```bash
sudo ANSIBLE_SHELL=/bin/bash PUBLIC_KEY_FILE=/tmp/ansible.pub bash bootstrap-ansible-user.sh
```

---

### `PUBLIC_KEY_FILE`

Путь к файлу публичного SSH-ключа.

Пример:

```bash
sudo PUBLIC_KEY_FILE=/tmp/ansible.pub bash bootstrap-ansible-user.sh
```

---

### `ANSIBLE_PUBLIC_KEY`

Публичный SSH-ключ, переданный напрямую через переменную.

Пример:

```bash
sudo ANSIBLE_PUBLIC_KEY="ssh-ed25519 AAAA... ansible-key" bash bootstrap-ansible-user.sh
```

> Если используются оба варианта, рекомендуется отдавать приоритет `PUBLIC_KEY_FILE`, так как файл проще проверить и безопаснее использовать в автоматизированном сценарии.

---

## Пример полного запуска

```bash
scp ~/.ssh/ansible.pub setup@192.0.2.10:/tmp/ansible.pub
scp scripts/bootstrap-ansible-user.sh setup@192.0.2.10:/tmp/

ssh setup@192.0.2.10
sudo PUBLIC_KEY_FILE=/tmp/ansible.pub bash /tmp/bootstrap-ansible-user.sh
```

После успешного выполнения скрипта:

```bash
ssh ansible@192.0.2.10
sudo whoami
```

Ожидаемый результат:

```text
root
```

---

## Проверка результата

### Проверка пользователя

```bash
id ansible
```

Ожидаемый результат:

```text
uid=... gid=... groups=...,sudo
```

---

### Проверка SSH-ключа

```bash
sudo ls -la /home/ansible/.ssh
sudo cat /home/ansible/.ssh/authorized_keys
```

Ожидаемые права:

```text
/home/ansible/.ssh              700
/home/ansible/.ssh/authorized_keys 600
```

---

### Проверка sudo

```bash
sudo -l -U ansible
```

Или войти под пользователем:

```bash
ssh ansible@<host>
sudo whoami
```

Ожидаемый результат:

```text
root
```

---

### Проверка через Ansible

После добавления машины в inventory:

```bash
ansible <host> -m ping
```

Проверка пользователя:

```bash
ansible <host> -m command -a "whoami"
```

Ожидаемый результат:

```text
ansible
```

Проверка повышения прав:

```bash
ansible <host> -m command -a "whoami" -b
```

Ожидаемый результат:

```text
root
```

---

## Безопасность

Скрипт использует следующие меры безопасности:

- SSH-доступ настраивается только по публичному ключу;
- пароль пользователя блокируется;
- sudo-доступ настраивается через отдельный файл в `/etc/sudoers.d`;
- sudoers-файл проверяется через `visudo`;
- права на `.ssh` и `authorized_keys` выставляются явно.

---

## Почему используется NOPASSWD

Ansible должен иметь возможность выполнять команды с `become: true` без интерактивного ввода пароля.

Поэтому для служебного пользователя используется:

```text
ansible ALL=(ALL) NOPASSWD:ALL
```

Это допустимо при выполнении условий:

- пользователь используется только для автоматизации;
- SSH-доступ разрешён только по ключу;
- приватный ключ хранится вне репозитория;
- доступ ограничивается через `AllowUsers`;
- после настройки применяется роль `security`.

---

## Где хранить ключи

Приватные ключи не должны храниться в репозитории.

Рекомендуемая схема:

```text
~/.ssh/ansible
~/.ssh/ansible.pub
```

В репозитории можно хранить только example-файлы:

```text
docs/examples/ansible.pub.example
```

или инструкции по созданию ключа.

---

## Создание SSH-ключа

Пример создания отдельного ключа для Ansible:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible -C "ansible-automation"
```

После этого публичный ключ будет находиться по пути:

```text
~/.ssh/ansible.pub
```

Приватный ключ:

```text
~/.ssh/ansible
```

Приватный ключ не должен попадать в Git.

---

## Повторный запуск скрипта

Скрипт рассчитан на повторный запуск.

Если пользователь уже существует, он не создаётся заново.

При повторном запуске скрипт обновляет:

- SSH-ключ;
- права на `.ssh`;
- sudoers-файл;
- членство в sudo-группе.

Это позволяет безопасно переинициализировать доступ при необходимости.

---

## Возможные ошибки

### `PUBLIC_KEY_FILE is not set`

Не указан путь к публичному ключу.

Решение:

```bash
sudo PUBLIC_KEY_FILE=/tmp/ansible.pub bash bootstrap-ansible-user.sh
```

---

### `Public key file not found`

Файл публичного ключа не найден.

Проверить:

```bash
ls -l /tmp/ansible.pub
```

---

### `File does not look like a valid SSH public key`

Файл не похож на публичный SSH-ключ.

Публичный ключ должен начинаться с одного из типов:

```text
ssh-ed25519
ssh-rsa
ecdsa-sha2-nistp256
```

---

### `Neither 'sudo' nor 'wheel' group exists`

На системе отсутствует стандартная группа для административного доступа.

Для Ubuntu и Astra Linux обычно используется группа:

```text
sudo
```

Для некоторых других дистрибутивов может использоваться:

```text
wheel
```

---

### `Invalid sudoers file generated`

Сгенерированный sudoers-файл не прошёл проверку `visudo`.

Скрипт в этом случае удаляет некорректный файл и завершает работу с ошибкой.

---

## Интеграция с Ansible inventory

После успешного bootstrap в inventory можно указать:

### Ubuntu

```ini
[ubuntu_hosts]
ubuntu ansible_host=<ip_address> ansible_user=ansible
```

### Astra Linux

```ini
[astra_hosts]
astra ansible_host=<ip_address> ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9
```

После этого машина готова к управлению через Ansible.

---

## Дальнейшая настройка

После выполнения bootstrap рекомендуется запустить playbook'и в следующем порядке:

```bash
ansible-playbook playbooks/base.yml
ansible-playbook playbooks/users.yml
ansible-playbook playbooks/security.yml
ansible-playbook playbooks/docker.yml
ansible-playbook playbooks/dev.yml
```

---

## Итог

Скрипт `bootstrap-ansible-user.sh` решает задачу первичной подготовки машины к управлению через Ansible.

Он не заменяет Ansible-роли, а только создаёт безопасную точку входа для дальнейшей автоматизации.

Финальная модель:

```text
setup/root/console
    ↓
bootstrap-ansible-user.sh
    ↓
ansible user
    ↓
Ansible roles
    ↓
готовая рабочая станция
```