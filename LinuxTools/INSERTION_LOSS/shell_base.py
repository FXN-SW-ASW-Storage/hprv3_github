"""
Unidiag shell/CLi module
"""

import argparse
import sys

from typing import Iterable


def module_executor(parser, argv=None, shell=True):
    """The executor for all parsers."""
    try:
        func = parser(argv)
    except argparse.ArgumentError as e:
        print(e, file=sys.stderr)
        if shell:
            sys.exit(2)
    returncode = 0
    try:
        ret = func()
    # pylint:disable=broad-exception-caught
    except Exception as e:
        print(f"Error when executing: {e!r}", file=sys.stderr)
        if shell:
            sys.exit(1)
        print("Result: Error")
    if isinstance(ret, int):
        returncode = ret
    elif isinstance(ret, Iterable):
        returncode, retstr = ret
        if retstr:
            print(retstr)

    if isinstance(returncode, int):
        if shell:
            sys.exit(returncode)
        print(f"Result: {'PASS' if returncode == 0 else 'FAIL'}")
    else:
        print("Error: return code is not an integer.", file=sys.stderr)
        if shell:
            sys.exit(1)
        print("Result: Error")
