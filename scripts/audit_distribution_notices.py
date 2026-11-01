#!/usr/bin/env python3
"""Inventory in-source notices. Not legal advice or a license determination."""
import argparse,hashlib,json,pathlib,re,stat,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
def referenced_license(root):
 # Do not follow symlinks: an external file would not accompany this package.
 path=root/'LICENSE.txt';record={'path':'LICENSE.txt'}
 try:
  mode=path.lstat().st_mode
  if stat.S_ISLNK(mode):record['status']='symlink'
  elif not stat.S_ISREG(mode):record['status']='not_regular'
  else:
   data=path.read_bytes()
   record.update(bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),
    status='present_unreviewed' if data.strip() else 'empty')
 except FileNotFoundError:record['status']='missing'
 except OSError as e:record.update(status='unreadable',error=type(e).__name__)
 return record

def audit(root=ROOT,source=None):
 rows=[]
 for line in (root/'hbide.hbp').read_text().splitlines():
  rel=line.strip()
  if not rel.endswith(('.prg','.c')) or rel.startswith('#'):continue
  path=root/rel;text=path.read_text();header=text.split('#include',1)[0]
  rows.append({'path':rel,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
   'gpl_notice':'GNU General Public License' in header,
   'harbour_exception':'special exception' in header,
   'copyright_notice':'Copyright' in header,
   'license_file_reference':'LICENSE.txt' in header})
 notices=[p.name for p in root.iterdir() if p.is_file() and p.name.lower().startswith(('license','copying','notice'))]
 license_record=referenced_license(root)
 missing=[r['path'] for r in rows if r['license_file_reference'] and license_record['status']!='present_unreviewed']
 unspecified=[r['path'] for r in rows if not r['gpl_notice']]
 return {'scope':'Local HBP source notice inventory only. Absence of a detected header is not proof of no license or ownership. Does not clear redistribution.',
  'source':source or subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  'referenced_license':license_record,'root_notice_files':notices,'sources':rows,'missing_referenced_license':missing,
  'without_detected_gpl_header':unspecified,'release_review_required':bool(missing or unspecified)}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check-release',action='store_true');p.add_argument('--source-revision',help='40-hex frozen export revision, avoids git lookup');a=p.parse_args();
 if a.source_revision and not re.fullmatch('[0-9a-f]{40}',a.source_revision):p.error('source revision must be 40 lowercase hex characters')
 d=audit(source=a.source_revision);print(json.dumps(d,indent=2));return 1 if a.check_release and d['release_review_required'] else 0
if __name__=='__main__':raise SystemExit(main())
