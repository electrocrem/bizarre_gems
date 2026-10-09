#!/usr/bin/env python3
"""Check store/listing.md against the Yandex Games draft field rules."""
import os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
text = open(os.path.join(ROOT, "store", "listing.md"), encoding="utf-8").read()
BANNED = re.compile(r"\b(free|top|best|бесплатн\w*|на русском языке)\b", re.I)
errors = []

def err(lang, field, msg): errors.append(f"[{lang}] {field}: {msg}")

for lang_block in re.split(r"^## ", text, flags=re.M)[1:]:
    lang, body = lang_block.split("\n", 1)
    lang = lang.strip()
    fields = {m.group(1): m.group(2).strip() for m in re.finditer(r"^### (\w+)\n(.*?)(?=^### |\Z)", body, flags=re.S | re.M)}
    title = fields.get("title", "")
    rules = {"title": (1, 50), "short": (0, 70), "seo": (50, 160), "about": (100, 1000), "howto": (100, 1000), "keywords": (0, 100)}
    for f, (lo, hi) in rules.items():
        v = fields.get(f)
        if v is None:
            err(lang, f, "missing"); continue
        n = len(v)
        status = "ok" if lo <= n <= hi else "OUT OF RANGE"
        print(f"{lang:3} {f:9} {n:5} chars  (limit {lo}-{hi})  {status}")
        if status != "ok": err(lang, f, f"{n} chars, needs {lo}-{hi}")
        if BANNED.search(v): err(lang, f, f"banned word: {BANNED.search(v).group(0)}")
        if f != "title" and title and title.lower() in v.lower(): err(lang, f, "repeats the title")
    if title and (not title[0].isupper() or title.isupper()): err(lang, "title", "must start with a capital, no all caps")
    seo = fields.get("seo", "")
    if seo and seo[-1] not in ".!": err(lang, "seo", "must end with . or !")
    if re.search(r"[(=/\\+_]", seo): err(lang, "seo", "contains ( = / \\ + _")
    short = fields.get("short", "")
    if short and not short[0].isupper(): err(lang, "short", "must start with a capital")
    if short.startswith(("\"", "«")) and short.endswith(("\"", "»")): err(lang, "short", "wrapped in quotes")
    kw = fields.get("keywords", "")
    if kw != kw.lower(): err(lang, "keywords", "must be lowercase")
    tags = [t.strip() for t in fields.get("tags", "").split(",") if t.strip()]
    print(f"{lang:3} tags      {len(tags):5} tags   (limit 20)  {'ok' if len(tags) <= 20 else 'TOO MANY'}")
    if len(tags) > 20: err(lang, "tags", f"{len(tags)} tags, max 20")

print("\n" + ("\n".join(errors) if errors else "all fields pass"))
sys.exit(1 if errors else 0)
