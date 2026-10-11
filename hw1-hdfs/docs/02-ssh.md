## 2. SSH для пользователя hadoop

`start-dfs.sh` запускается на NameNode и по ssh стартует демоны на всех нодах (включая саму NN) от пользователя `hadoop`. Поэтому `hadoop` с NN должен заходить на все ноды без пароля.

Нужно, чтобы был выполнен шаг 1 (пользователь `hadoop` уже есть на нодах).

### Скрипт

Запускать на edge-ноде от `team` из корня репозитория:

```bash
bash hw1-hdfs/scripts/02-setup-ssh.sh
```

Что делает:
- создает ключ `~/.ssh/id_ed25519` у `hadoop` на `team-31-nn` (если ключ уже есть, берет существующий)
- добавляет публичный ключ в `authorized_keys` у `hadoop` на `team-31-nn`, `team-31-00`, `team-31-01`
- заполняет `known_hosts` у `hadoop` на NN через `ssh-keyscan`, чтобы не было вопроса про fingerprint
- в конце запускает проверку

Скрипт можно запускать повторно.

Отдельно проверка:

```bash
bash hw1-hdfs/scripts/02-check-ssh.sh
```

Должно быть так:

```
=== Checking ssh for hadoop from team-31-nn ===
OK   team-31-nn
OK   team-31-00
OK   team-31-01
OK   localhost
All nodes OK
```

### Вручную

На NN от `hadoop`:

```bash
ssh -i ~/.ssh/team_internal team@team-31-nn
sudo -iu hadoop
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519   # если ключа еще нет
cat ~/.ssh/id_ed25519.pub
```

На каждой ноде (nn, 00, 01) от `hadoop`:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo '<публичный ключ>' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Потом с NN от `hadoop` зайти на каждую ноду и ответить `yes`:

```bash
for h in team-31-nn team-31-00 team-31-01 localhost; do ssh $h hostname; done
```
