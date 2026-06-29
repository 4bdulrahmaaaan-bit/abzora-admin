import re, os
directory = r'c:\Users\AAA\Documents\abzio\lib'
for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                for i, line in enumerate(lines):
                    # We are looking for strings that contain a question mark used where a rupee symbol should be
                    # Common patterns: '? 500', '?$price', '?${price}'
                    if re.search(r'[\'"]\s*\?\s*(?:[0-9]|\$|\{)', line):
                        print(f'{filepath}:{i+1}:{line.strip()}')
                    elif re.search(r'[\'"][^\'"]*\b\?\s*(?:[0-9]|\$|\{)', line):
                        print(f'{filepath}:{i+1}:{line.strip()}')
            except:
                pass
