#!/usr/bin/env python3

from pathlib import Path
from collections import defaultdict
from typing import List, Dict, Optional
import argparse
import shutil
import fnmatch
import sys

def gather_files(directory: Path) -> List[Path]:
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

def build_files_dict(root_paths: List[Path]) -> Dict[str, List[Path]]:
    """
    Builds a dictionary of file keys to their full paths.
    """
    files_dict: Dict[str, List[Path]] = defaultdict(list)
    for root_path in root_paths:
        files = gather_files(root_path)
        for file in files:
            key = strip_prefix_and_extension(file, root_path)
            files_dict[key].append(file)
    return files_dict

def list_files(files_dict: Dict[str, List[Path]], src_root: Path, inc_root: Path, filter_pattern: Optional[str] = None) -> None:
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

def fuzzy_filter(keys: List[str], pattern: str) -> List[str]:
    """
    Filters the list of keys using a fuzzy pattern match.
    Pattern matching is case insensitive and supports partial matches.
    """
    pattern = pattern.lower()
    return [key for key in keys if fnmatch.fnmatch(key.lower(), f"*{pattern}*")]

def move_files(
    files_dict: Dict[str, List[Path]], 
    from_key: str, 
    to_key: str, 
    src_root: Path, 
    inc_root: Path, 
    move_dir: bool = False,
    no_name: bool = False,
    fuzzy: bool = False
) -> None:
    """
    Moves files associated with a key to a new location.
    Supports directory moves and option to exclude filename in destination.
    """
    if fuzzy:
        matched_keys = fuzzy_filter(list(files_dict.keys()), from_key)
        if not matched_keys:
            print(f"No matches found for pattern: {from_key}")
            return
    else:
        matched_keys = [from_key] if from_key in files_dict else []

    for key in matched_keys:
        for file in files_dict[key]:
            # Determine if the file is from Src or Inc
            if str(file).startswith(str(src_root)):
                new_file = src_root / to_key
            elif str(file).startswith(str(inc_root)):
                new_file = inc_root / to_key
            else:
                continue

            # Handle --no-name option
            if no_name:
                new_file = new_file / file.stem
            else:
                new_file = new_file / key

            # Add the file extension back
            new_file = new_file.with_suffix(file.suffix)

            # Handle --dir option
            if move_dir:
                new_file = Path(str(new_file).replace(key, to_key))

            # Create parent directories if they don't exist
            new_file.parent.mkdir(parents=True, exist_ok=True)

            # Check if the destination exists and raise an error if it does
            if new_file.exists():
                print(f"Destination path '{new_file}' already exists. Skipping.")
                continue

            # Perform the move operation
            shutil.move(str(file), str(new_file))
            print(f"Moved: {file} -> {new_file}")

def delete_files(files_dict: Dict[str, List[Path]], from_key: str, fuzzy: bool = False) -> None:
    """
    Deletes files associated with a key or pattern.
    Supports fuzzy matching for the key.
    """
    if fuzzy:
        matched_keys = fuzzy_filter(list(files_dict.keys()), from_key)
        if not matched_keys:
            print(f"No matches found for pattern: {from_key}")
            return
    else:
        matched_keys = [from_key] if from_key in files_dict else []

    for key in matched_keys:
        for file in files_dict[key]:
            file.unlink()
            print(f"Deleted: {file}")

def main() -> None:
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
    move_parser.add_argument("-d", "--dir", action="store_true", help="Move as a directory")
    move_parser.add_argument("-n", "--no-name", action="store_true", help="Exclude filename in destination")
    move_parser.add_argument("--fuzzy", action="store_true", help="Fuzzy match the from key (requires --no-name)")

    delete_parser = subparsers.add_parser("delete")
    delete_parser.add_argument("key", help="The key to delete")
    delete_parser.add_argument("--fuzzy", action="store_true", help="Fuzzy match the key to delete")

    create_parser = subparsers.add_parser("create")
    create_parser.add_argument("key", help="The key for the new file pair")

    args = parser.parse_args()

    if args.command == "list":
        list_files(files_dict, src_root, inc_root)
    elif args.command == "search":
        list_files(files_dict, src_root, inc_root, filter_pattern=args.filter_pattern)
    elif args.command == "move":
        if args.fuzzy and not args.no_name:
            print("Error: --fuzzy can only be used with --no-name.")
            sys.exit(1)
        move_files(files_dict, args.from_key, args.to_key, src_root, inc_root, args.dir, args.no_name, args.fuzzy)
    elif args.command == "delete":
        delete_files(files_dict, args.key, args.fuzzy)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
