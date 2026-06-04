# Personal To-Do CLI

This is a small Python command-line application for managing a persistent
personal to-do list.

## Run

```sh
python3 main.py
```

Run one command at a time:

```sh
python3 main.py add "Buy milk" --description "Two bottles" --due-date 2026-06-10
python3 main.py list --upcoming
python3 main.py complete 1
python3 main.py edit 1 --title "Buy oat milk"
python3 main.py delete 1
```

Run checks:

```sh
python3 main.py --self-test
```

## Modules

- `main.py`: entry point that parses commands and delegates work.
- `tasks.py`: defines the `Task` class and task operations.
- `storage.py`: saves and loads tasks from SQLite in `tasks.db`.
- `cli.py`: prompt and table-display helpers.
- `README.md`: install, run, and module documentation.

## Storage

Tasks persist in a local SQLite database with this schema:

```sql
tasks(id, title, description, due_date, completed)
```

Set `TODO_DB_PATH=/path/to/tasks.db` to store the database somewhere else.
