#!/usr/bin/env python3
"""Concise NSE & SE coverage summary."""

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
    en_snake = {k for k in en_entries if is_snake_case(k)}
    en_phrase = {k for k in en_entries if not is_snake_case(k)}

    print(f'{"=" * 70}')
    print(f'{target_name} — {len(en_entries)} keys ({len(en_snake)} snake + {len(en_phrase)} phrase)')
    print(f'{"=" * 70}')

    # Collect untranslated phrase keys (same across all languages)
    all_langs_untranslated_phrase = None

    for lang in REGISTERED_LANGS:
        if lang == 'en':
            continue
        path = os.path.join(IOS_DIR, path_tmpl.format(lang=lang))
        lang_entries = parse_strings(path)

        missing = sorted([k for k in en_entries if k not in lang_entries])
        untranslated = sorted([k for k in lang_entries if k in en_entries and lang_entries[k] == en_entries[k]])
        translated_snake = [k for k in en_snake if k in lang_entries and has_non_ascii(lang_entries.get(k, ''))]

        total = len(lang_entries)
        cov = 100 * (total - len(untranslated)) / total if total else 0

        untranslated_snake = [k for k in untranslated if is_snake_case(k)]
        untranslated_phrase = [k for k in untranslated if not is_snake_case(k)]

        if all_langs_untranslated_phrase is None:
            all_langs_untranslated_phrase = set(untranslated_phrase)
        else:
            all_langs_untranslated_phrase &= set(untranslated_phrase)

        print(f'  [{lang:8s}] {total:3d} entries | cov={cov:5.1f}% | missing={len(missing):2d} | '
              f'ut_snake={len(untranslated_snake):3d} | ut_phrase={len(untranslated_phrase):2d} | '
              f'translated_snake={len(translated_snake):3d}')

        if missing:
            for k in missing:
                print(f'           MISSING: "{k}" = "{en_entries[k][:50]}"')

    # Print common untranslated phrase keys
    if all_langs_untranslated_phrase:
        print(f'\n  Phrase keys untranslated in ALL languages ({len(all_langs_untranslated_phrase)}):')
        for k in sorted(all_langs_untranslated_phrase):
            print(f'    "{k}" = "{en_entries[k]}"')

    # Print snake_case keys that need translation (sample)
    print(f'\n  Snake_case keys needing translation ({len(en_snake)} total):')
    for k in sorted(en_snake):
        v = en_entries[k]
        short_v = v[:55] + '...' if len(v) > 55 else v
        print(f'    "{k}" = "{short_v}"')
    print()
