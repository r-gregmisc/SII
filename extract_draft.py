import json

found_content = ""
with open("/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/.system_generated/logs/transcript_full.jsonl", "r") as f:
    for line in f:
        data = json.loads(line)
        if "tool_calls" in data:
            for call in data["tool_calls"]:
                if call["name"] in ["write_to_file", "replace_file_content", "multi_replace_file_content"]:
                    args = call.get("args", {})
                    if "manuscript_draft.md" in args.get("TargetFile", ""):
                        if "CodeContent" in args:
                            found_content = args["CodeContent"]

if found_content:
    with open("extracted_draft.md", "w") as f:
        f.write(found_content)
    print("Extracted draft length:", len(found_content))
else:
    print("Could not find CodeContent for manuscript_draft.md")

