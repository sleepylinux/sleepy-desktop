import argparse

from sleepy.subcommands import scheme, shell, wallpaper
from sleepy.utils.paths import wallpapers_dir
from sleepy.utils.scheme import get_scheme_names, scheme_variants
from sleepy.utils.wallpaper import get_wallpaper


def parse_args() -> tuple[argparse.ArgumentParser, argparse.Namespace]:
    parser = argparse.ArgumentParser(prog="sleepy", description="Sleepy shell appearance and IPC helper")
    parser.add_argument("-v", "--version", action="store_true")
    commands = parser.add_subparsers(title="subcommands", metavar="COMMAND")

    shell_parser = commands.add_parser("shell", help="message the running Sleepy shell")
    shell_parser.set_defaults(cls=shell.Command)
    shell_parser.add_argument("message", nargs="*")
    shell_parser.add_argument("-s", "--show", action="store_true")

    scheme_parser = commands.add_parser("scheme", help="manage the colour scheme")
    scheme_commands = scheme_parser.add_subparsers(title="subcommands")
    list_parser = scheme_commands.add_parser("list")
    list_parser.set_defaults(cls=scheme.List)
    list_parser.add_argument("-n", "--names", action="store_true")
    list_parser.add_argument("-f", "--flavours", action="store_true")
    list_parser.add_argument("-m", "--modes", action="store_true")
    list_parser.add_argument("-v", "--variants", action="store_true")
    get_parser = scheme_commands.add_parser("get")
    get_parser.set_defaults(cls=scheme.Get)
    get_parser.add_argument("-n", "--name", action="store_true")
    get_parser.add_argument("-f", "--flavour", action="store_true")
    get_parser.add_argument("-m", "--mode", action="store_true")
    get_parser.add_argument("-v", "--variant", action="store_true")
    set_parser = scheme_commands.add_parser("set")
    set_parser.set_defaults(cls=scheme.Set)
    set_parser.add_argument("--notify", action="store_true")
    set_parser.add_argument("-r", "--random", action="store_true")
    set_parser.add_argument("-n", "--name", choices=get_scheme_names())
    set_parser.add_argument("-f", "--flavour")
    set_parser.add_argument("-m", "--mode", choices=["dark", "light"])
    set_parser.add_argument("-v", "--variant", choices=scheme_variants)

    wallpaper_parser = commands.add_parser("wallpaper", help="manage the wallpaper")
    wallpaper_parser.set_defaults(cls=wallpaper.Command)
    wallpaper_parser.add_argument("-p", "--print", nargs="?", const=get_wallpaper(), metavar="PATH")
    wallpaper_parser.add_argument("-r", "--random", nargs="?", const=wallpapers_dir, metavar="DIR")
    wallpaper_parser.add_argument("-f", "--file")
    wallpaper_parser.add_argument("-n", "--no-filter", action="store_true")
    wallpaper_parser.add_argument("-t", "--threshold", type=float, default=0.8)
    wallpaper_parser.add_argument("-N", "--no-smart", action="store_true")
    return parser, parser.parse_args()
