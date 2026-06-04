"""SQLite persistence for tasks."""

from __future__ import annotations

import os
import sqlite3
from pathlib import Path
from typing import Dict, List, Optional


DB_PATH = Path(os.environ.get("TODO_DB_PATH", Path(__file__).with_name("tasks.db")))


def configure(db_path: Path) -> None:
    global DB_PATH
    DB_PATH = Path(db_path)


def connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                due_date TEXT,
                completed INTEGER NOT NULL DEFAULT 0
            )
            """
        )
        conn.commit()


def row_to_dict(row: sqlite3.Row) -> Dict[str, object]:
    return {
        "id": row["id"],
        "title": row["title"],
        "description": row["description"],
        "due_date": row["due_date"],
        "completed": bool(row["completed"]),
    }


def add_task(title: str, description: str = "", due_date: Optional[str] = None) -> int:
    if not title.strip():
        raise ValueError("Task title is required.")
    init_db()
    with connect() as conn:
        cursor = conn.execute(
            "INSERT INTO tasks (title, description, due_date, completed) VALUES (?, ?, ?, 0)",
            (title.strip(), description.strip(), due_date.strip() if due_date else None),
        )
        conn.commit()
        return int(cursor.lastrowid)


def list_tasks(completed: Optional[bool] = None) -> List[Dict[str, object]]:
    init_db()
    sql = "SELECT id, title, description, due_date, completed FROM tasks"
    params = []
    if completed is not None:
        sql += " WHERE completed = ?"
        params.append(1 if completed else 0)
    sql += " ORDER BY completed ASC, COALESCE(due_date, '9999-12-31') ASC, id ASC"
    with connect() as conn:
        return [row_to_dict(row) for row in conn.execute(sql, params).fetchall()]


def get_task(task_id: int) -> Optional[Dict[str, object]]:
    init_db()
    with connect() as conn:
        row = conn.execute(
            "SELECT id, title, description, due_date, completed FROM tasks WHERE id = ?",
            (task_id,),
        ).fetchone()
    if row is None:
        return None
    return row_to_dict(row)


def update_task(
    task_id: int,
    title: Optional[str] = None,
    description: Optional[str] = None,
    due_date: Optional[str] = None,
    completed: Optional[bool] = None,
) -> bool:
    init_db()
    updates = []
    params = []
    if title is not None:
        if not title.strip():
            raise ValueError("Task title cannot be empty.")
        updates.append("title = ?")
        params.append(title.strip())
    if description is not None:
        updates.append("description = ?")
        params.append(description.strip())
    if due_date is not None:
        updates.append("due_date = ?")
        params.append(due_date.strip() or None)
    if completed is not None:
        updates.append("completed = ?")
        params.append(1 if completed else 0)
    if not updates:
        return get_task(task_id) is not None
    params.append(task_id)
    with connect() as conn:
        cursor = conn.execute("UPDATE tasks SET " + ", ".join(updates) + " WHERE id = ?", params)
        conn.commit()
        return cursor.rowcount > 0


def delete_task(task_id: int) -> bool:
    init_db()
    with connect() as conn:
        cursor = conn.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
        conn.commit()
        return cursor.rowcount > 0
