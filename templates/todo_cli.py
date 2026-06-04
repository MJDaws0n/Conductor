"""CLI prompting and display helpers."""

from __future__ import annotations

from typing import Iterable

from tasks import Task


def prompt(message: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    value = input(f"{message}{suffix}: ").strip()
    return value if value else default


def confirm(message: str) -> bool:
    return input(f"{message} [y/N]: ").strip().lower() in {"y", "yes"}


def format_task(task: Task) -> str:
    status = "done" if task.completed else "open"
    due = task.due_date or "-"
    description = task.description or "-"
    return f"{task.id:<4} {status:<6} {due:<12} {task.title:<28} {description}"


def display_tasks(tasks: Iterable[Task]) -> None:
    items = list(tasks)
    if not items:
        print("No tasks found.")
        return
    print(f"{'id':<4} {'status':<6} {'due':<12} {'title':<28} description")
    print("-" * 72)
    for task in items:
        print(format_task(task))
