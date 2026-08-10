import json

found_content = ""
with open("/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/.system_generated/logs/transcript_full.jsonl", "r") as f:
    for line in f:
        data = json.loads(line)
        if "content" in data:
            if "MPO-domain saturation limit" in data["content"] and "ABG restoration" in data["content"]:
                # This could be a tool output
                found_content = data["content"]

if found_content:
    with open("extracted_full.md", "w") as f:
        f.write(found_content)
    print("Successfully extracted full content.")
else:
    print("Not found in content.")
