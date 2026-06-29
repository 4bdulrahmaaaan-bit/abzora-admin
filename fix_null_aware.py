import subprocess
import re
import os
from collections import defaultdict

def main():
    print("Running flutter analyze...")
    result = subprocess.run(["flutter", "analyze"], capture_output=True, text=True, shell=True)
    lines = result.stdout.split('\n')
    
    errors_by_file = defaultdict(set)
    for line in lines:
        line = line.strip()
        m = re.search(r'(error|warning|info)\s+-\s+(.*?)\s+-\s+(.*?):(\d+):(\d+)\s+-\s+(.*)', line)
        if m:
            file_path = m.group(3).strip()
            line_num = int(m.group(4))
            errors_by_file[file_path].add(line_num)
            
    print(f"Found errors in {len(errors_by_file)} files.")
    
    files_modified = 0
    for file_path, err_lines in errors_by_file.items():
        try:
            if not os.path.exists(file_path):
                continue
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.readlines()
            
            modified = False
            for ln in err_lines:
                idx = ln - 1
                if idx >= 0 and idx < len(content):
                    original_line = content[idx]
                    
                    # We look for a ' ? ' and change it to ' ?? '
                    # We also handle things like `? ''` which might be ` ? ''` or `?'`
                    # The most common broken patterns from ?? -> ? replacement:
                    
                    # 1. space ? space
                    new_line = re.sub(r'(\s)\?(\s)', r'\1??\2', original_line)
                    
                    # 2. space ? followed by quote or bracket
                    if new_line == original_line:
                        new_line = re.sub(r'(\s)\?([\'"\[])', r'\1??\2', original_line)
                        
                    # 3. right paren or bracket, space, ?, bracket/quote
                    if new_line == original_line:
                        new_line = re.sub(r'([\)\]])\s?\?(\s*[\'"\[\w])', r'\1 ??\2', original_line)

                    if new_line != original_line:
                        content[idx] = new_line
                        modified = True
                        
            if modified:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.writelines(content)
                files_modified += 1
                
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            
    print(f"Modified {files_modified} files.")

if __name__ == '__main__':
    main()
