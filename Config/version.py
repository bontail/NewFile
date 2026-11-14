"""The release tag, archive name and bundle metadata share one version."""

import pathlib
import re


def read_version():
    version = (pathlib.Path(__file__).resolve().parent.parent / "VERSION").read_text().strip()
    if not re.fullmatch(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", version):
        raise SystemExit("VERSION must contain a version such as 3.1.0")
    return version


if __name__ == "__main__":
    print(read_version())
