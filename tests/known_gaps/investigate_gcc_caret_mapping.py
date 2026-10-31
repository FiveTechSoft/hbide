import subprocess,json,pathlib,re
out=pathlib.Path('/tmp/hbide-gcc-caret-evidence');out.mkdir(exist_ok=True)
results=[]
for text in ['\treturn unknown_name;','\t\treturn unknown_name;',' \treturn unknown_name;','\treturn unknown_name+unknown_name;']:
 src=out/'bad.c';src.write_text('int main(void) {\n'+text+'\n}\n')
 for name,flags in [('default',[]),('byte',['-fdiagnostics-column-unit=byte']),('tab4',['-ftabstop=4']),('tab16',['-ftabstop=16']),('no-caret',['-fno-diagnostics-show-caret'])]:
  p=subprocess.run(['gcc','-fsyntax-only',*flags,str(src)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,env={'PATH':'/usr/bin:/bin','LC_ALL':'C'})
  lines=p.stdout.decode().splitlines();rendered=None;caret=None
  for i,l in enumerate(lines):
   m=re.match(r'\s*2 \| (.*)',l)
   if m and i+1<len(lines):
    rendered=m[1];a=lines[i+1].split('| ',1)
    if len(a)==2 and '^' in a[1]:caret=a[1].index('^')+1
    break
  candidates=[]
  if rendered is not None and caret:
   for width in range(1,33):
    expanded='';offsets=[]
    for pos,c in enumerate(text,1):
     start=len(expanded)+1
     expanded+=(' '*(width-len(expanded)%width)) if c=='\t' else c
     if start<=caret<=len(expanded):offsets.append(pos)
    if expanded==rendered:candidates+=offsets
  resolved=next(iter(set(candidates))) if len(set(candidates))==1 else None
  results.append({'text':text,'mode':name,'resolved_character':resolved,'expected':text.index('unknown_name')+1,'safe_fallback':resolved is None,'output':p.stdout.decode()})
assert all(x['resolved_character']==x['expected'] for x in results if x['mode']!='no-caret')
assert all(x['resolved_character'] is None for x in results if x['mode']=='no-caret')
(out/'results.json').write_text(json.dumps({'scope':'Investigation only, not integrated. ASCII exact source rendering + caret can yield unambiguous char under multiple tab widths; absent/mismatched/ambiguous evidence must keep original number. Need source matching and Unicode/cropping handling before integration.','results':results},indent=2)+'\n')
print(len(results),'PASS pure mapping evidence cases, no product mutation')
