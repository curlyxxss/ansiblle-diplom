````md
# Machine Initialization Pipeline

## Назначение документа

Данный документ описывает реалистичный процесс инициализации новой рабочей станции перед её дальнейшей настройкой через Ansible.

Документ фиксирует границу между двумя этапами:

1. **Bootstrap provisioning** — первичная подготовка машины и создание служебного пользователя для Ansible.
2. **Configuration management** — дальнейшая централизованная настройка машины через Ansible-роли.

Такой подход позволяет избежать ручной настройки рабочих станций после первичной инициализации и обеспечивает воспроизводимость конфигурации.

---

## Общая схема процесса

```text
Установка ОС
    ↓
Первичный доступ к машине
    ↓
Bootstrap пользователя ansible
    ↓
Проверка SSH и sudo
    ↓
Добавление машины в inventory
    ↓
Bootstrap Python для Astra Linux
    ↓
Запуск Ansible playbook'ов
    ↓
Проверка результата
    ↓
Отключение временного доступа
```

---

## 1. Подготовка на управляющей машине

На управляющей машине должен быть установлен Ansible и склонирован репозиторий проекта.

```bash
git clone <repository_url>
cd diplom-ansible
```

Также должен быть подготовлен SSH-ключ, который будет использоваться для подключения Ansible к целевым машинам.

Пример:

```bash
ls -l ~/.ssh/ansible
ls -l ~/.ssh/ansible.pub
```

Приватные ключи не должны храниться в репозитории.

В репозитории допускается хранить только:

- example-файлы;
- инструкции;
- шаблоны публичных ключей.

---

## 2. Установка операционной системы

На целевую машину устанавливается одна из поддерживаемых ОС:

- Ubuntu 24.04;
- Astra Linux Orel.

Во время установки создаётся временный пользователь первичной настройки, например:

```text
setup
```

Назначение временного пользователя:

- получить первичный доступ к машине;
- запустить bootstrap-скрипт;
- создать служебного пользователя `ansible`.

Временный пользователь не является финальным пользователем разработчика и не используется для дальнейшей автоматизации.

---

## 3. Первичный доступ к машине

Первичный доступ может быть выполнен несколькими способами.

### Вариант 1. Через SSH

Если после установки ОС уже доступен SSH, подключение выполняется через временного пользователя:

```bash
ssh setup@<host>
```

Далее на машину передаются публичный ключ и bootstrap-скрипт:

```bash
scp ~/.ssh/ansible.pub setup@<host>:/tmp/ansible.pub
scp scripts/bootstrap-ansible-user.sh setup@<host>:/tmp/
```

После этого скрипт запускается на целевой машине:

```bash
ssh setup@<host>
sudo PUBLIC_KEY_FILE=/tmp/ansible.pub bash /tmp/bootstrap-ansible-user.sh
```

---

### Вариант 2. Через локальную консоль

Если SSH ещё не настроен, первичный доступ выполняется через консоль виртуальной машины или физического устройства.

В этом случае bootstrap-скрипт можно запустить локально, передав публичный ключ через переменную:

```bash
sudo ANSIBLE_PUBLIC_KEY="ssh-ed25519 AAAA... ansible-key" bash bootstrap-ansible-user.sh
```

Этот вариант полезен для полностью чистых машин, где удалённый доступ ещё отсутствует.

---

### Вариант 3. Через cloud-init / autoinstall

В более зрелой инфраструктуре создание служебного пользователя может быть выполнено автоматически через:

- cloud-init;
- autoinstall;
- preseed;
- другой механизм первичного provisioning.

В этом случае пользователь `ansible`, SSH-ключ и sudo-доступ создаются ещё на этапе установки ОС.

Данный вариант является наиболее удобным для массового развёртывания, но в текущем проекте рассматривается как направление дальнейшего развития.

---

## 4. Bootstrap служебного пользователя Ansible

На этапе bootstrap создаётся служебный пользователь:

```text
ansible
```

Данный пользователь предназначен только для автоматизации и не используется как рабочая учётная запись разработчика.

Bootstrap-скрипт выполняет следующие действия:

- создаёт пользователя `ansible`;
- создаёт домашний каталог;
- создаёт директорию `/home/ansible/.ssh`;
- устанавливает публичный ключ в `authorized_keys`;
- задаёт корректные права доступа;
- добавляет пользователя в группу `sudo`;
- создаёт файл `/etc/sudoers.d/ansible`;
- настраивает `NOPASSWD`;
- проверяет sudoers-файл через `visudo`;
- блокирует парольный вход для пользователя.

---

## 5. Проверка SSH-доступа под пользователем ansible

После выполнения bootstrap необходимо проверить SSH-доступ.

```bash
ssh ansible@<host>
```

После входа проверяется возможность выполнения команд с повышением привилегий:

```bash
sudo whoami
```

Ожидаемый результат:

```text
root
```

Также можно выполнить проверку с управляющей машины через Ansible:

```bash
ansible <host> -m ping
ansible <host> -m command -a "whoami"
ansible <host> -m command -a "whoami" -b
```

Ожидаемая логика:

```text
whoami без become -> ansible
whoami с become  -> root
```

---

## 6. Добавление машины в inventory

После успешной проверки SSH-доступа машина добавляется в inventory.

Пример для Ubuntu:

```ini
[ubuntu_hosts]
ubuntu-01 ansible_host=<ip_address> ansible_user=ansible
```

Пример для Astra Linux:

```ini
[astra_hosts]
astra-01 ansible_host=<ip_address> ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9
```

Для тестовой среды с NAT и пробросом портов можно использовать:

```ini
[astra_hosts]
astra ansible_host=<host_ip> ansible_port=2222 ansible_user=ansible ansible_python_interpreter=/usr/local/bin/python3.9

[ubuntu_hosts]
ubuntu ansible_host=<host_ip> ansible_port=2223 ansible_user=ansible

[workstations:children]
astra_hosts
ubuntu_hosts
```

---

## 7. Bootstrap Python для Astra Linux

Для Ubuntu этот этап не требуется, так как система уже содержит подходящий Python.

Для Astra Linux требуется отдельная установка Python 3.9, так как системный Python не подходит для полноценной работы современных версий Ansible.

Скрипт установки:

```text
scripts/install-python.sh
```

Пример запуска:

```bash
scp scripts/install-python.sh ansible@<host>:/tmp/
ssh ansible@<host>
sudo bash /tmp/install-python.sh
```

После установки Python доступен по пути:

```text
/opt/python/3.9
```

Для Ansible используется стабильная точка входа:

```text
/usr/local/bin/python3.9
```

В inventory для Astra Linux необходимо указать:

```ini
ansible_python_interpreter=/usr/local/bin/python3.9
```

Проверка:

```bash
ansible astra -m ping
```

Ожидаемый результат:

```text
pong
```

---

## 8. Запуск Ansible playbook'ов

После выполнения bootstrap машина полностью управляется через Ansible.

Рекомендуемый порядок запуска:

```bash
ansible-playbook playbooks/base.yml
ansible-playbook playbooks/users.yml
ansible-playbook playbooks/security.yml
ansible-playbook playbooks/docker.yml
ansible-playbook playbooks/dev.yml
```

Порядок важен:

| Этап | Назначение |
|---|---|
| `base` | базовая настройка ОС |
| `users` | управление пользователями |
| `security` | применение политик безопасности |
| `docker` | установка Docker |
| `dev` | настройка среды разработчика |

---

## 9. Проверка результата

После применения всех ролей выполняется проверка состояния машины.

### Проверка доступности

```bash
ansible all -m ping
```

### Проверка пользователя Ansible

```bash
ansible all -m command -a "whoami"
```

Ожидаемый результат:

```text
ansible
```

Проверка sudo:

```bash
ansible all -m command -a "whoami" -b
```

Ожидаемый результат:

```text
root
```

---

### Проверка hostname

```bash
ansible all -m command -a "hostname"
```

---

### Проверка безопасности

На целевой машине:

```bash
sudo ufw status verbose
sudo fail2ban-client status
sudo sshd -T | grep -i allowusers
```

Ожидаемые результаты:

- firewall активен;
- входящие соединения запрещены по умолчанию;
- SSH разрешён;
- fail2ban активен;
- SSH-доступ ограничен разрешёнными пользователями.

---

### Проверка Docker

```bash
docker --version
docker ps
```

Для Ubuntu ожидается полноценная поддержка Docker Engine и Docker Compose plugin.

Для Astra Linux Docker поддерживается ограниченно из-за устаревшей доступной версии Docker Engine.

---

### Проверка dev-среды

Для Ubuntu:

```bash
python3 --version
pipx list
uv --version
ruff --version
pytest --version
git config --global --list
```

Для Astra Linux:

```bash
/usr/local/bin/python3.9 --version
/usr/local/bin/python3.9 -m pipx list
~/.local/bin/uv --version
~/.local/bin/ruff --version
git config --global --list
```

---

## 10. Очистка временного доступа

После того как доступ под пользователем `ansible` проверен, временный пользователь `setup` больше не нужен для автоматизации.

Его можно удалить или заблокировать через роль `users`.

Пример:

```yaml
users:
  - name: setup
    state: absent
```

Удаление временного пользователя рекомендуется выполнять только после проверки:

```bash
ssh ansible@<host>
sudo whoami
```

Ожидаемый результат:

```text
root
```

---

## 11. Итоговая модель пользователей

После инициализации используются разные типы пользователей.

### Служебный пользователь Ansible

```text
ansible
```

Назначение:

- подключение Ansible;
- выполнение автоматизации;
- sudo-доступ;
- не используется для ежедневной работы.

### Пользователь разработчика

```text
devuser
```

Назначение:

- ежедневная работа;
- Docker;
- Python dev-инструменты;
- Git;
- разработка.

Такое разделение уменьшает смешение административных и пользовательских задач.

---

## 12. Итоговая схема

```text
1. Установка ОС
2. Создание временного пользователя setup
3. Первичный доступ через SSH или консоль
4. Запуск bootstrap-скрипта
5. Создание пользователя ansible
6. Проверка SSH и sudo
7. Добавление машины в inventory
8. Bootstrap Python для Astra Linux
9. Запуск Ansible-ролей
10. Проверка состояния машины
11. Удаление или блокировка временного пользователя
```

---

## Вывод

Процесс инициализации новой машины разделён на два уровня:

1. **Bootstrap provisioning** — минимальная подготовка машины и создание служебного пользователя `ansible`.
2. **Configuration management** — полная настройка машины через Ansible-роли.

Такой подход позволяет избежать постоянной ручной настройки, сохраняет воспроизводимость конфигурации и обеспечивает безопасную модель управления рабочими станциями.

После завершения pipeline машина становится частью управляемой инфраструктуры и может централизованно обслуживаться через Ansible.
````
