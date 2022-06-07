import sys
import re

def find_single_pattern(pat: str, text: str) -> re.Match:
    pattern = re.compile(pat)
    existing_match = None
    existing_match_offset = None
    for offset, line in enumerate(text.splitlines()):
        offset += 1
        match = pattern.match(line)
        if match is None: continue
        if existing_match is not None:
            assert existing_match_offset is not None
            raise ValueError(f"Duplicate matches for {pat!r}: Line {offset} and {existing_match_offset}")
        existing_match = match
        existing_match_offset = offset
    if existing_match is None:
        raise ValueError(f"Expected to find match for {pat!r}")
    return existing_match

INDENT = ' ' * 4

def apply_indent(current_indent, inner):
    for line in inner:
        yield current_indent + line

EXTRA_ENUM_OPS = [f'OP_PUSH_{i}' for i in range(0, 201)]
EXTRA_LABELS = [f'push_{i}' for i in range(0, 201)]

def extra_opcodes(start):
    for i, label in enumerate(EXTRA_LABELS):
        yield f'OP_PUSH_{i} = {start + i},'

def extra_evals(mode):
    for i in range(0, 201):
        if mode == 'goto':
            yield f'push_{i}: {{'
        elif mode == 'case':
            yield f'case OP_PUSH_{i}: {{'
        else:
            raise AssertionError
        yield f'{INDENT}*stack++ = {i};'
        yield f'{INDENT}DISPATCH();'
        yield '}'

def extra_nested_switch():
    for i in range(0, 201):
        # NOTE: Need `\` at end, because inside macro
        yield f'case OP_PUSH_{i}: goto push_{i}; \\'

def extra_jump_table():
    for i in range(0, 201):
        yield f'&&push_{i},'    

EXPAND_PATTERN = re.compile(r'// [$]EXPAND: ([\w_]+\(.*\))')

def rewrite_interpreter(text: str):
    existing_num_opcodes = int(find_single_pattern(r"#define NUM_OPCODES (\d+)", text).group(1))
    yield f'#define NUM_OPCODES {existing_num_opcodes + 201}'
    for line in text.splitlines():
        if (m := EXPAND_PATTERN.search(line)) is not None:
            yield from apply_indent(' ' * m.start(), eval(m.group(1), globals(), None))
        else:
            yield line

if __name__ == "__main__":
    with open(sys.argv[1], 'rt') as f:
        with open('simple_interpreter_expanded.c', 'wt') as out:
            for line in rewrite_interpreter(f.read()):
                out.write(line)
                out.write('\n')


    