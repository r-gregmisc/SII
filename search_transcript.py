import json

with open("/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/.system_generated/logs/transcript.jsonl", "r") as f:
    for line in f:
        data = json.loads(line)
        if "content" in data:
            if "MPO-domain" in data["content"] or "ABG 30 dB" in data["content"] or "Ching et al. threshold-shift" in data["content"]:
                print(f"Found in step {data.get('step_index')}, length: {len(data['content'])}")
                # Find the surrounding text
                content = data["content"]
                idx = content.find("MPO-domain")
                if idx == -1:
                    idx = content.find("ABG 30")
                if idx != -1:
                    print(content[max(0, idx-500):min(len(content), idx+500)])
                print("-" * 50)
