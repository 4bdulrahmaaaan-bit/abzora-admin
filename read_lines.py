import os

target_file = r'c:\Users\AAA\Documents\abzio\lib\screens\vendor\add_product_screen.dart'

with open(target_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Show the specific lines with their contexts
print("Lines 57-59:")
for i in range(56, 59):
    print(f"{i+1}: {lines[i].rstrip()}")

print("\nLines 155-157:")
for i in range(154, 157):
    print(f"{i+1}: {lines[i].rstrip()}")
    
print("\nLines 166-168:")
for i in range(165, 168):
    print(f"{i+1}: {lines[i].rstrip()}")

print("\nLines 653-657:")
for i in range(652, 657):
    print(f"{i+1}: {lines[i].rstrip()}")

print("\nLines 2023-2025:")
for i in range(2022, 2025):
    print(f"{i+1}: {lines[i].rstrip()}")

print("\nLines 2034-2036:")
for i in range(2033, 2036):
    print(f"{i+1}: {lines[i].rstrip()}")
