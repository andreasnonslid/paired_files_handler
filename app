#!/usr/bin/env python3

from pathlib import Path
from collections import defaultdict
import argparse
import shutil
import fnmatch

def gather_files(directory: Path) -> list[Path]:
    """
    Returns a list of all file paths (excluding directories) in 'directory'.
    """
    return [p for p in directory.rglob('*') if p.is_file()]

def strip_prefix_and_extension(filepath: Path, root_path: Path) -> str:
    """
    Given a file path and a root path, return the file path:
      1. with the root prefix removed, and
      2. with its extension stripped off.
    """
    relative_path = filepath.relative_to(root_path)
    path_without_ext = relative_path.with_suffix('')
    return str(path_without_ext)

def build_files_dict(root_paths):
    files_dict = defaultdict(list)
    for root_path in root_paths:
        files = gather_files(root_path)
        for file in files:
            key = strip_prefix_and_extension(file, root_path)
            files_dict[key].append(file)
    return files_dict

def list_files(files_dict, src_root, inc_root, filter_pattern=None):
    paired = []
    only_src = []
    only_inc = []

    for key, paths in files_dict.items():
        in_src = any(str(p).startswith(str(src_root)) for p in paths)
        in_inc = any(str(p).startswith(str(inc_root)) for p in paths)
        
        if in_src and in_inc:
            paired.append(key)
        elif in_src:
            only_src.append(key)
        else:
            only_inc.append(key)

    if filter_pattern:
        paired = fuzzy_filter(paired, filter_pattern)
        only_src = fuzzy_filter(only_src, filter_pattern)
        only_inc = fuzzy_filter(only_inc, filter_pattern)

    print("Paired files (in both Src and Inc):")
    for key in sorted(paired):
        print(f"  {key}")
    
    print("\nFiles only in Src:")
    for key in sorted(only_src):
        print(f"  {key}")
    
    print("\nFiles only in Inc:")
    for key in sorted(only_inc):
        print(f"  {key}")

def fuzzy_filter(keys, pattern):
    """
    Filters the list of keys using a fuzzy pattern match.
    Pattern matching is case insensitive and supports partial matches.
    """
    pattern = pattern.lower()
    return [key for key in keys if fnmatch.fnmatch(key.lower(), f"*{pattern}*")]

def move_files(files_dict, from_key, to_key, src_root, inc_root):
    if from_key not in files_dict:
        print(f"No files found for key: {from_key}")
        return

    for file in files_dict[from_key]:
        if str(file).startswith(str(src_root)):
            new_file = src_root / (to_key + file.suffix)
        elif str(file).startswith(str(inc_root)):
            new_file = inc_root / (to_key + file.suffix)
        else:
            continue

        new_file.parent.mkdir(parents=True, exist_ok=True)

        shutil.move(str(file), str(new_file))
        print(f"Moved: {file} -> {new_file}")

def delete_files(files_dict, from_key):
    if from_key not in files_dict:
        print(f"No files found for key: {from_key}")
        return

    for file in files_dict[from_key]:
        file.unlink()
        print(f"Deleted: {file}")

def create_files(src_root, inc_root, file_key):
    """
    Creates a new source (.c) file in Core/Src and a new header (.h) file in Core/Inc.
    """
    src_file = src_root / (file_key + ".c")
    inc_file = inc_root / (file_key + ".h")

    src_file.parent.mkdir(parents=True, exist_ok=True)
    inc_file.parent.mkdir(parents=True, exist_ok=True)

    if not src_file.exists():
        with open(src_file, "w") as f:
            f.write(f"// Source file for {file_key}\n\nint main() {{\n    return 0;\n}}\n")
        print(f"Created: {src_file}")
    else:
        print(f"File already exists: {src_file}")

    if not inc_file.exists():
        guard = file_key.replace("/", "_").upper()
        with open(inc_file, "w") as f:
            f.write(f"#ifndef {guard}_H\n#define {guard}_H\n\n// Header for {file_key}\n\n#endif // {guard}_H\n")
        print(f"Created: {inc_file}")
    else:
        print(f"File already exists: {inc_file}")

def main():
    src_root = Path('Core/Src')
    inc_root = Path('Core/Inc')
    root_paths = [src_root, inc_root]

    files_dict = build_files_dict(root_paths)

    parser = argparse.ArgumentParser(description="File Pair Manager")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("list")

    search_parser = subparsers.add_parser("search")
    search_parser.add_argument("filter_pattern", help="Fuzzy filter pattern")

    move_parser = subparsers.add_parser("move")
    move_parser.add_argument("--from", dest="from_key", required=True)
    move_parser.add_argument("--to", dest="to_key", required=True)

    delete_parser = subparsers.add_parser("delete")
    delete_parser.add_argument("key", help="The key to delete")

    create_parser = subparsers.add_parser("create")
    create_parser.add_argument("key", help="The key for the new file pair")

    args = parser.parse_args()

    if args.command == "list":
        list_files(files_dict, src_root, inc_root)
    elif args.command == "search":
        list_files(files_dict, src_root, inc_root, filter_pattern=args.filter_pattern)
    elif args.command == "move":
        move_files(files_dict, args.from_key, args.to_key, src_root, inc_root)
    elif args.command == "delete":
        delete_files(files_dict, args.key)
    elif args.command == "create":
        create_files(src_root, inc_root, args.key)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
