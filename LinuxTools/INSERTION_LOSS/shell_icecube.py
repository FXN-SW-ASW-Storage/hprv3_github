"""
Icecube shell execution module
"""

import argparse
import importlib
import sys
from unidiag.modules.shell.shell_base import module_executor

BUS_MODULES = {
    "cpu",
    "gpio",
    "i2c",
    "mdio",
    "pcie",
    "scsi",
    "spi",
    "usb",
}

# This only indicates **implemented** modules.
# All modules can be imported normally if available.
SUPPORTED_MODULES = {"i2c", "spi", "upgrade", "fan", "led", "osfp"}

PLATFORM_NAME = "icecube"


def import_argparser(module: str, parser_name: str = "module_argparser"):
    """import argparser from module"""
    if module in BUS_MODULES:
        module_path = f"unidiag.modules.bus.{module}"
    else:
        module_path = f"unidiag.modules.{module}"
    module_imported = importlib.import_module(
        module_path + f".{module}_{PLATFORM_NAME}"
    )
    return getattr(module_imported, parser_name)


icecube_cli_argparser = argparse.ArgumentParser(add_help=True)
icecube_cli_argparser.add_argument("module")
icecube_cli_argparser.add_argument(
    "--debug", dest="debug", action="store_true", default=False
)

if __name__ == "__main__":
    shell_args, extra_args = icecube_cli_argparser.parse_known_args()
    if shell_args.module == "list":
        print("Supported commands are:")
        for cmd in SUPPORTED_MODULES | {"list"}:
            print(f"  {cmd}")
        sys.exit()
    try:
        module_parser = import_argparser(shell_args.module)
    # pylint:disable=broad-exception-caught
    except Exception as err:
        print(
            f'Failed to load "module_argparser" from module {shell_args.module}: {err!r}.',
            file=sys.stderr,
        )
        if shell_args.debug:
            import traceback

            traceback.print_exc()
        sys.exit(1)
    module_executor(module_parser, argv=extra_args, shell=True)
