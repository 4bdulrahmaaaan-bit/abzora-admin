import json
import os

log_path = r'C:\Users\AAA\.gemini\antigravity\brain\fd04db35-dcfc-484a-823b-8b048405bed5\.system_generated\logs\transcript.jsonl'

def patch_file(target_file, search_text, replace_text):
    if not os.path.exists(target_file):
        return
    with open(target_file, 'r', encoding='utf-8') as f:
        content = f.read()
    if search_text in content:
        content = content.replace(search_text, replace_text)
        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Applied patch to {os.path.basename(target_file)}")
    else:
        print(f"Failed to find match in {os.path.basename(target_file)}")

print("Applying patches...")
with open(log_path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        try:
            data = json.loads(line)
            if 'tool_calls' in data:
                for call in data['tool_calls']:
                    func_name = call.get('name')
                    if func_name in ['replace_file_content', 'multi_replace_file_content']:
                        args = call.get('args', {})
                        tf_str = args.get('TargetFile', '""')
                        tf = json.loads(tf_str)
                        
                        if 'profile_screen.dart' in tf:
                            desc_str = args.get('Description', '""')
                            desc = json.loads(desc_str).lower()
                            
                            # We only want the specific patches that removed duplicates!
                            if 'duplicate' in desc or 'redundant' in desc or 'cleanup' in desc or 'remove' in desc:
                                if func_name == 'replace_file_content':
                                    target = json.loads(args.get('TargetContent', '""'))
                                    replace = json.loads(args.get('ReplacementContent', '""'))
                                    patch_file(tf, target, replace)
                                elif func_name == 'multi_replace_file_content':
                                    chunks_str = args.get('ReplacementChunks', '[]')
                                    chunks = json.loads(chunks_str)
                                    for chunk in chunks:
                                        target = chunk.get('TargetContent', '')
                                        replace = chunk.get('ReplacementContent', '')
                                        patch_file(tf, target, replace)
        except Exception as e:
            pass
print("Done patching.")
