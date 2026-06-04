#!/usr/bin/env python3
"""Entry point for the generated to-do CLI."""

from __future__ import annotations

import argparse
import shlex
import sys
import tempfile
from pathlib import Path
from typing import List, Optional

import cli
import storage
import tasks


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage a persistent personal to-do list.")
    parser.add_argument("--self-test", action="store_true", help="Run non-interactive checks")
    subcommands = parser.add_subparsers(dest="command")

    add = subcommands.add_parser("add", help="Add a new task")
    add.add_argument("title")
    add.add_argument("-d", "--description", default="")
    add.add_argument("--due-date", default=None)

    list_cmd = subcommands.add_parser("list", help="List tasks")
    list_cmd.add_argument("--completed", action="store_true", help="Only show completed tasks")
    list_cmd.add_argument("--upcoming", action="store_true", help="Only show incomplete tasks")

    complete = subcommands.add_parser("complete", help="Mark a task as completed")
    complete.add_argument("task_id", type=int)

    edit = subcommands.add_parser("edit", help="Edit a task")
    edit.add_argument("task_id", type=int)
    edit.add_argument("--title", default=None)
    edit.add_argument("--description", default=None)
    edit.add_argument("--due-date", default=None)
    edit.add_argument("--completed", choices=["yes", "no"], default=None)

    delete = subcommands.add_parser("delete", help="Delete a task")
    delete.add_argument("task_id", type=int)

    subcommands.add_parser("interactive", help="Start the interactive prompt")
    return parser


def completed_filter(args: argparse.Namespace) -> Optional[bool]:
    if getattr(args, "completed", False):
        return True
    if getattr(args, "upcoming", False):
        return False
    return None


def handle_args(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    storage.init_db()
    if args.self_test:
        run_self_test()
        return 0
    if args.command is None or args.command == "interactive":
        return interactive_loop(parser)
    if args.command == "add":
        task = tasks.add_task(args.title, args.description, args.due_date)
        print(f"Added task #{task.id}: {task.title}")
        return 0
    if args.command == "list":
        cli.display_tasks(tasks.list_tasks(completed=completed_filter(args)))
        return 0
    if args.command == "complete":
        task = tasks.mark_completed(args.task_id, True)
        if task is None:
            print("Task not found.")
            return 1
        print(f"Completed task #{task.id}: {task.title}")
        return 0
    if args.command == "edit":
        completed = None
        if args.completed == "yes":
            completed = True
        elif args.completed == "no":
            completed = False
        task = tasks.edit_task(args.task_id, args.title, args.description, args.due_date, completed)
        if task is None:
            print("Task not found.")
            return 1
        print(f"Updated task #{task.id}: {task.title}")
        return 0
    if args.command == "delete":
        if tasks.delete_task(args.task_id):
            print(f"Deleted task #{args.task_id}.")
            return 0
        print("Task not found.")
        return 1
    parser.print_help()
    return 1


def interactive_loop(parser: argparse.ArgumentParser) -> int:
    print("To-do CLI. Type help for commands or exit to quit.")
    while True:
        try:
            line = input("todo> ").strip()
        except EOFError:
            print("")
            return 0
        if not line:
            continue
        if line in {"exit", "quit"}:
            return 0
        if line == "help":
            parser.print_help()
            continue
        try:
            args = parser.parse_args(shlex.split(line))
            if args.command is None:
                parser.print_help()
                continue
            handle_args(args, parser)
        except SystemExit:
            print("Invalid command. Type help.")
    return 0


def run_self_test() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        storage.configure(Path(tmpdir) / "tasks.db")
        storage.init_db()
        first = tasks.add_task("Buy milk", "Two bottles", "2026-06-10")
        second = tasks.add_task("Read docs", "", None)
        assert first.id > 0
        assert second.id > first.id
        assert len(tasks.list_tasks(completed=False)) == 2
        completed = tasks.mark_completed(first.id)
        assert completed is not None
        assert completed.completed is True
        edited = tasks.edit_task(second.id, title="Read storage docs", description="sqlite module")
        assert edited is not None
        assert edited.title == "Read storage docs"
        assert len(tasks.list_tasks(completed=True)) == 1
        assert tasks.delete_task(first.id) is True
        assert tasks.get_task(first.id) is None
    print("SELF_TEST_OK")


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return handle_args(args, parser)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
