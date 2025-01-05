import re

def join_lines(lines, join):
    if join:
        return '\n'.join(lines)
    return lines

def remove_up_to_match(multiline_string, pattern):
    lines = multiline_string.splitlines()
    match_index = next((i for i, line in enumerate(lines) if re.search(pattern, line)), None)
    if match_index is not None:
        lines = lines[match_index + 1:]
    return '\n'.join(lines)

def strip_empty_lines(multiline_string, join=True):
    all_lines = multiline_string.splitlines()
    lines = [line for line in all_lines if line.strip()]
    return join_lines(lines, join)

def strip_leading_lines(multiline_string, join=True):
    all_lines = multiline_string.splitlines()
    non_empty_index = next((i for i, line in enumerate(all_lines) if line.strip()), len(all_lines))
    lines = all_lines[non_empty_index:]
    return join_lines(lines, join)

def strip_trailing_lines(multiline_string, join=True):
    all_lines = multiline_string.splitlines()
    non_empty_index = len(all_lines) - 1
    while non_empty_index >= 0 and not all_lines[non_empty_index].strip():
        non_empty_index -= 1
    lines = all_lines[:non_empty_index + 1]
    return join_lines(lines, join)