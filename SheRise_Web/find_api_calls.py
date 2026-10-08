import re

with open('frontend_dist/assets/index-DHxhsTGL.js', 'r', encoding='utf-8') as f:
    content = f.read()

matches = re.findall(r'fetch\([`\'\"](/api/[^`\'\"?]+)', content)
for m in sorted(set(matches)):
    print(m)
