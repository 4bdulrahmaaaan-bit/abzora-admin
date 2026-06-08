import json
import os

log_path = r'C:\Users\AAA\.gemini\antigravity\brain\fd04db35-dcfc-484a-823b-8b048405bed5\.system_generated\logs\transcript.jsonl'
count = 0
with open(log_path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if 'multi_replace_file_content' in line or 'replace_file_content' in line:
            print(f"Line {i} contains replacement tool")
            count += 1
            if count > 5:
                break
