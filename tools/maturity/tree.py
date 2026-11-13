# Druckt den Roblox-Fragebogen (IARC) kompakt als Baum: Fragen [Typ] und Optionen mit IDs.
import json, sys
q = json.load(open(sys.argv[1]))["questionnaire"]
def t(s): return (s or "").strip().replace("\n", " ")[:160]
def sec(s, d):
    print("  " * d + f"S {s['id']} {t(s.get('name'))}")
    for x in s.get("questions") or []: ques(x, d + 1)
def ques(x, d):
    print("  " * d + f"Q {x['id']} [{x.get('type')}] {t(x.get('text'))}")
    for o in x.get("options") or []:
        m = o.get("metadata") or {}
        flags = " ".join(f"{k}={m[k]}" for k in ("content-descriptor", "content-descriptor-contains", "ViolativeOption") if k in m)
        print("  " * (d + 1) + f"O {o['id']} {t(o.get('text'))} {flags}")
        for c in o.get("childQuestions") or []: ques(c, d + 2)
        for c in o.get("childSections") or []: sec(c, d + 2)
for s in q["sections"]: sec(s, 0)
