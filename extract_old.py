import json

found_content = ""
with open("/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/.system_generated/logs/transcript.jsonl", "r") as f:
    for line in f:
        data = json.loads(line)
        if "tool_calls" in data:
            for call in data["tool_calls"]:
                if call["name"] == "write_to_file" or call["name"] == "replace_file_content" or call["name"] == "multi_replace_file_content":
                    args = call.get("args", {})
                    # Look for CodeContent or ReplacementContent
                    content = args.get("CodeContent", "")
                    if "MPO-domain saturation limit" in content and "ABG restoration" in content:
                        found_content = content

if found_content:
    with open("extracted_manuscript.md", "w") as f:
        f.write(found_content)
    print("Successfully extracted older manuscript.")
else:
    print("Could not find the content in tool_calls. Let me check the user input or model output text.")

