# Role: users

## Назначение

Роль `users` управляет учетными записями пользователей на рабочих станциях.

Роль предназначена для:
- создания пользователей;
- назначения shell;
- добавления в группы;
- установки SSH-ключей;
- управления sudo-доступом через `/etc/sudoers.d`.

## Особенности

- пользователи описываются через переменные;
- реальные учетные записи задаются в `group_vars` или `host_vars`;
- роль не редактирует `/etc/sudoers` напрямую;
- синтаксис sudoers проверяется через `visudo`;
- поддерживается состояние `present` и `absent`.

## Переменные

### defaults

- `users_manage_accounts` — включает или отключает управление учетными записями;
- `users_default_shell` — shell по умолчанию;
- `users_default_groups` — группы по умолчанию;
- `users_remove_unmanaged` — зарезервировано для будущей логики;
- `users` — список пользователей (по умолчанию пустой).

### пример описания пользователя

```yaml
users:
  - name: devuser
    state: present
    shell: /bin/bash
    groups:
      - sudo
    ssh_keys:
      - "~/.ssh/diplom.pub"
    sudo: true
    sudo_nopasswd: true
