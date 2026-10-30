#!/usr/bin/env python3
"""Inventory in-source notices. Not legal advice or a license determination."""
import argparse,hashlib,json,pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
def audit():
 rows=[]
 for line in (ROOT/'hbide.hbp').read_text().splitlines():
  rel=line.strip()
  if not rel.endswith(('.prg','.c')) or rel.startswith('#'):continue
  path=ROOT/rel;text=path.read_text();header=text.split('#include',1)[0]
  rows.append({'path':rel,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
   'gpl_notice':'GNU General Public License' in header,
   'harbour_exception':'special exception' in header,
   'copyright_notice':'Copyright' in header,
   'license_file_reference':'LICENSE.txt' in header})
 notices=[p.name for p in ROOT.iterdir() if p.is_file() and p.name.lower().startswith(('license','copying','notice'))]
 missing=[r['path'] for r in rows if r['license_file_reference'] and not (ROOT/'LICENSE.txt').is_file()]
 unspecified=[r['path'] for r in rows if not r['gpl_notice']]
 return {'scope':'Local HBP source notice inventory only. Absence of a detected header is not proof of no license or ownership. Does not clear redistribution.',
  'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  'root_notice_files':notices,'sources':rows,'missing_referenced_license':missing,
  'without_detected_gpl_header':unspecified,'release_review_required':bool(missing or unspecified)}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check-release',action='store_true');a=p.parse_args();d=audit();print(json.dumps(d,indent=2));return 1 if a.check_release and d['release_review_required'] else 0
if __name__=='__main__':raise SystemExit(main())
