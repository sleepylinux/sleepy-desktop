from sleepy.parser import parse_args
from sleepy.utils.io import log

VERSION = "0.2.0"


def main() -> None:
    try:
        parser, args = parse_args()
        if args.version:
            print(VERSION)
        elif "cls" in args:
            args.cls(args).run()
        else:
            parser.print_help()
    except KeyboardInterrupt:
        log("Exiting...")
