import subprocess
from argparse import Namespace


class Command:
    def __init__(self, args: Namespace) -> None:
        self.args = args

    def run(self) -> None:
        command = ["sleepy-shell-ipc", "call", *self.args.message]
        if self.args.show:
            command = ["sleepy-shell-ipc", "show"]
        subprocess.run(command, check=True)
