"""Task model and task-level operations."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional

import storage


@dataclass
class Task:
    id: int
    title: str
    description: str = ""
    due_date: Optional[str] = None
    completed: bool = False

    @classmethod
    def from_row(cls, row: Dict[str, object]) -> "Task":
        return cls(
            id=int(row["id"]),
            title=str(row["title"]),
            description=str(row.get("description") or ""),
            due_date=row.get("due_date") if row.get("due_date") else None,
            completed=bool(row.get("completed")),
        )


def add_task(title: str, description: str = "", due_date: Optional[str] = None) -> Task:
    task_id = storage.add_task(title, description, due_date)
    task = get_task(task_id)
    if task is None:
        raise RuntimeError("Task was not saved.")
    return task


def list_tasks(completed: Optional[bool] = None) -> List[Task]:
    return [Task.from_row(row) for row in storage.list_tasks(completed=completed)]


def get_task(task_id: int) -> Optional[Task]:
    row = storage.get_task(task_id)
    if row is None:
        return None
    return Task.from_row(row)


def edit_task(
    task_id: int,
    title: Optional[str] = None,
    description: Optional[str] = None,
    due_date: Optional[str] = None,
    completed: Optional[bool] = None,
) -> Optional[Task]:
    changed = storage.update_task(
        task_id,
        title=title,
        description=description,
        due_date=due_date,
        completed=completed,
    )
    if not changed:
        return None
    return get_task(task_id)


def mark_completed(task_id: int, completed: bool = True) -> Optional[Task]:
    return edit_task(task_id, completed=completed)


def delete_task(task_id: int) -> bool:
    return storage.delete_task(task_id)
