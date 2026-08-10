import re

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

def print_context(query):
    print("--- " + query + " ---")
    idx = text.find(query)
    if idx != -1:
        print(text[max(0, idx-50):min(len(text), idx+200)])
    else:
        print("Not found")

print_context("conductive blocks attenuate")
print_context("age-specific RECD values")
print_context("Dead region detection")
print_context("L_{gain}")
