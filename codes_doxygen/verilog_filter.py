#!/usr/bin/env python3
"""Turn one commented Verilog file into a C summary Doxygen can parse.

Doxygen has no Verilog parser. This filter keeps the Doxygen comments and
the module ports, and drops the Verilog body. Run by Doxygen, not by hand.
"""

import re
import sys
from pathlib import Path


def clean_block(raw):
    lines = []
    for line in raw.splitlines():
        lines.append(re.sub(r"^\s*\*\s?", "", line).rstrip())
    text = "\n".join(lines).strip()
    return text


def blocks(text):
    found = []
    i = 0
    while True:
        start = text.find("/**", i)
        if start < 0:
            break
        end = text.find("*/", start + 3)
        if end < 0:
            break
        found.append(clean_block(text[start + 3:end]))
        i = end + 2
    return found


def module_name(text):
    match = re.search(r"\bmodule\s+([A-Za-z_][A-Za-z0-9_]*)", text)
    return match.group(1) if match else "module"


def ports(text):
    """Ports of the first module, taken from trailing ///< notes."""
    match = re.search(r"\bmodule\b", text)
    if not match:
        return []
    head = text[match.start():]
    # Stop at the end of the port list. Modules with no ports stop at ';'.
    semi = head.find(";")
    region = head[:semi] if semi >= 0 else head
    found = []
    for line in region.splitlines():
        note = re.search(
            r"\b([A-Za-z_][A-Za-z0-9_]*)\s*,?\s*///<\s*(.*?)\s*$",
            line,
        )
        if note and note.group(1) not in {"input", "output", "inout", "wire", "reg", "integer"}:
            found.append((note.group(1), note.group(2)))
    return found


def relative_path(filename):
    path = Path(filename).resolve()
    parts = path.parts
    if "codes_doxygen" in parts:
        idx = parts.index("codes_doxygen")
        return str(Path(*parts[idx + 1:]))
    return path.name


def page_id(rel):
    token = re.sub(r"[^A-Za-z0-9]+", "_", rel).strip("_")
    if not token or token[0].isdigit():
        token = "p_" + token
    return token


def rewrite_file_block(block, rel):
    lines = []
    for line in block.splitlines():
        if line.startswith("@file"):
            lines.append('@file "' + rel + '"')
        else:
            lines.append(line)
    return "\n".join(lines).strip()


def emit(filename):
    text = Path(filename).read_text(encoding="utf-8")
    rel = relative_path(filename)
    name = module_name(text)
    docs = blocks(text)
    file_doc = rewrite_file_block(docs[0], rel) if docs else f"@file {rel}"
    detail = ""
    if len(docs) > 1:
        # The second block repeats @brief. Keep the prose under it.
        detail_lines = []
        for line in docs[1].splitlines():
            if line.startswith("@brief") or line.startswith("@file"):
                continue
            detail_lines.append(line)
        detail = "\n".join(detail_lines).strip()
    port_lines = ports(text)
    pid = page_id(rel)

    print("/**")
    for line in file_doc.splitlines():
        print(" * " + line if line else " *")
    if detail:
        print(" *")
        for line in detail.splitlines():
            print(" * " + line if line else " *")
    if port_lines:
        print(" *")
        print(" * Ports:")
        for pname, note in port_lines:
            safe = note.replace("*/", "* /")
            print(f" * - {pname}: {safe}")
    print(" */")
    print()
    # A unique page name, because several files share a Verilog module name.
    print("/**")
    print(f" * @page {pid} {name}")
    brief = ""
    for line in file_doc.splitlines():
        if line.startswith("@brief"):
            brief = line[len("@brief"):].strip()
            break
    if brief:
        print(" *")
        print(f" * {brief}")
    if port_lines:
        print(" *")
        for pname, note in port_lines:
            safe = note.replace("*/", "* /")
            print(f" * @param {pname} {safe}")
    print(" */")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write("usage: verilog_filter.py FILE\n")
        sys.exit(2)
    emit(sys.argv[1])
