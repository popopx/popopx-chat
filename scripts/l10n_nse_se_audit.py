#!/usr/bin/env python3
"""NSE & SE localization coverage audit with missing key details."""

import re
import os

IOS_DIR = '/Users/elliot/simple-chat/POPOPX/apps/ios'

TARGETS = {
    'NSE': 'POPOP NSE/{lang}.lproj/Localizable.strings',
    'SE': 'POPOP SE/{lang}.lproj/Localizable.strings',
}

REGISTERED_LANGS = [
    'en', 'ru', 'de', 'fr', 'it', 'nl', 'cs',
    'zh-Hans', 'zh-Hant', 'es', 'pl', 'ja', 'th',
    'fi', 'uk', 'bg', 'tr', 'hu',
]


def parse_strings(path):
    entries = {}
    if not os.path.exists(path):
        return entries
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    pattern = re.compile(
        r'"((?:[^"\\]|\\.)*)"'
        r'\s*=\s*'
        r'"((?:[^"\\]|\\.)*?)"'
        r'\s*;',
        re.DOTALL
    )
    for m in pattern.finditer(content):
        entries[m.group(1)] = m.group(2)
    return entries


def has_non_ascii(s):
    return any(ord(c) > 127 for c in s)


def is_snake_case(key):
    return '_' in key and re.match(r'^[a-z][a-z0-9_]*$', key)


for target_name, path_tmpl in TARGETS.items():
    en_path = os.path.join(IOS_DIR, path_tmpl.format(lang='en'))
    en_entries = parse_strings(en_path)

    print('=' * 80)
    print(f'{target_name} TARGET — English baseline: {len(en_entries)} keys')
    print('=' * 80)

    # Categorize English keys
    en_snake = {k: v for k, v in en_entries.items() if is_snake_case(k)}
    en_phrase = {k: v for k, v in en_entries.items() if not is_snake_case(k)}
    print(f'  snake_case keys: {len(en_snake)}')
    print(f'  phrase keys:     {len(en_phrase)}')
    print()

    # List all English keys for reference
    print('--- English keys (full list) ---')
    for k in sorted(en_entries.keys()):
        v = en_entries[k]
        tag = 'S' if is_snake_case(k) else 'P'
        display_v = v[:60] + '...' if len(v) > 60 else v
        print(f'  [{tag}] "{k}" = "{display_v}"')
    print()

    for lang in REGISTERED_LANGS:
        if lang == 'en':
            continue
        path = os.path.join(IOS_DIR, path_tmpl.format(lang=lang))
        lang_entries = parse_strings(path)

        missing = sorted([k for k in en_entries if k not in lang_entries])
        untranslated = []
        for k in sorted(lang_entries.keys()):
            if k in en_entries and lang_entries[k] == en_entries[k]:
                untranslated.append(k)

        total = len(lang_entries)
        coverage = 100 * (total - len(untranslated)) / total if total > 0 else 0

        # Snake vs phrase breakdown
        present_snake = [k for k in en_snake if k in lang_entries]
        missing_snake = [k for k in en_snake if k not in lang_entries]
        untranslated_snake = [k for k in untranslated if is_snake_case(k)]
        untranslated_phrase = [k for k in untranslated if not is_snake_case(k)]

        print(f'[{lang}] {total} entries | coverage={coverage:.1f}% | missing={len(missing)} | untranslated={len(untranslated)}')
        print(f'  snake: present={len(present_snake)}, missing={len(missing_snake)}, untranslated={len(untranslated_snake)}')
        print(f'  phrase: untranslated={len(untranslated_phrase)}')

        if missing:
            print(f'  MISSING KEYS ({len(missing)}):')
            for k in missing:
                v = en_entries[k][:60] + '...' if len(en_entries[k]) > 60 else en_entries[k]
                tag = 'S' if is_snake_case(k) else 'P'
                print(f'    [{tag}] "{k}" = "{v}"')

        if untranslated_phrase:
            print(f'  UNTRANSLATED phrase keys ({len(untranslated_phrase)}):')
            for k in untranslated_phrase:
                print(f'    "{k}" = "{lang_entries[k]}"')

        print()
