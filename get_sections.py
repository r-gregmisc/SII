import re

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

def print_section(title):
    print("--- " + title + " ---")
    idx = text.find(title)
    if idx != -1:
        print(text[idx:idx+1000])
    else:
        print("Not found")

print_section("### I. Conductive component correction")
print_section("### M. Infant RECD scaling")
print_section("### F. Dead region detection")
print_section("L_{gain}")
