# Bootstrap Python for Astra Linux

## Назначение

Скрипт `scripts/install-python.sh` предназначен для установки дополнительной версии Python в Astra Linux в изолированный каталог без замены системного интерпретатора.

## Зачем это нужно

Astra Linux Orel в базовой конфигурации использует устаревшую версию Python, несовместимую с современной версией `ansible-core`. Для обеспечения совместимости с Ansible устанавливается отдельная версия Python в каталог `/opt/python/<version>`.

## Особенности

- не заменяет системный `python3`
- использует `make altinstall`
- поддерживает логирование
- поддерживает проверку контрольной суммы
- проверяет, установлена ли нужная версия ранее
- создаёт удобные симлинки в `/usr/local/bin`

## Пример запуска

```bash
sudo bash scripts/install-python.sh --version 3.9.19
```
## Пример с контрольной суммой

sudo bash scripts/install-python.sh --version 3.9.19 --sha256 <sha256>
## Проверка результата

python3.9 --version
pip3.9 --version

# Использование в Ansible
## Для astra linux в inventory необходимо указать
ansible_python_interpreter=/usr/local/bin/python3.9

---

# Как вызывать его вручную

Из корня проекта:

```bash
scp scripts/install-python.sh astra:/home/devuser/
ssh astra "chmod +x /home/devuser/install-python.sh && sudo bash /home/devuser/install-python.sh --version 3.9.19"
