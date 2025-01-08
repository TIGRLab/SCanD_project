from pathlib import Path
import pandas as pd

lines = Path('VALiDATe-labels.txt').read_text().splitlines()
data = {"label": [], "name": [], "abbreviation": [], "tissue": [], "comment": []}
last = 0

# Parse GM labels
for i, l in enumerate(lines[1:], 1):
    if not l.strip():
        last = i
        break
    vals = l.split(" ")
    data["label"].append(int(vals[0].strip()))
    data["name"].append(vals[1].strip())
    data["abbreviation"].append(vals[2].strip())
    data["tissue"].append("GM")
    data["comment"].append("n/a")

# Parse WM labels
for i, l in enumerate(lines[last + 2:], last + 2):
    if not l.strip():
        last = i
        break
    vals = l.split(" ")
    comment = "n/a"
    if "(" in l:
        l, comment = l.split("(")
        comment = comment.replace(")", "").strip()

    if l[2:].strip().lower().startswith("not used"):
        data["name"].append("not_used")
        data["abbreviation"].append("n/a")
    else:
        data["name"].append(vals[1].strip())
        try:
            data["abbreviation"].append(vals[2].strip())
        except IndexError:
            data["abbreviation"].append("n/a")
    data["label"].append(int(vals[0].strip()))
    data["tissue"].append("WM")
    data["comment"].append(comment)

# Parse Other section
for i, l in enumerate(lines[last + 2:], last + 2):
    if not l.strip():
        last = i
        break
    vals = l.split(" ")
    comment = "n/a"
    if "(" in l:
        l, comment = l.split("(")
        comment = comment.replace(")", "").strip()

    if l[2:].strip().lower().startswith("not used"):
        data["name"].append("not_used")
        data["abbreviation"].append("n/a")
    else:
        data["name"].append(vals[1].strip())
        try:
            data["abbreviation"].append(vals[2].strip())
        except IndexError:
            data["abbreviation"].append("n/a")
    data["label"].append(int(vals[0].strip()))
    data["tissue"].append("Other")
    data["comment"].append(comment)

# Write out
df[["label", "tissue", "abbreviation", "name", "comment"]].to_csv("tpl-VALiDATe29_atlas-VALiDATe_dseg.tsv", sep="\t", index=None)
