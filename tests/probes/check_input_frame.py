"""Verify an isolated frame probe. Never activates swapping in the IDE."""
import json,pathlib,subprocess,sys
exe,result=sys.argv[1:]
r=subprocess.run([exe,result],capture_output=True,timeout=8)
a=json.loads(pathlib.Path(result).read_text())
checks={
 'process_exit':r.returncode==0,
 'nine_normal_two_nointernals_calls':len(a)==11,
 'plain_inkey_poll':a[0][:2]==['poll',[]],
 'timed_inkey_wait':a[1][:2]==['wait',[.01]],
 'masked_wait':a[2][:2]==['wait',[.01,128]],
 'nil_mask_poll':a[3][:2]==['poll',[None,128]],
 'zero_arg_wait':a[4][:2]==['wait',[0]],
 'nonnumeric_single_wait_core_semantics':a[5][:2]==['wait',['bad']],
 'eval_inkey_wait':a[6][:2]==['wait',[.01]],
 'read_get_wait':a[7][:2]==['wait',[0]],
 'accept_C_entry_no_inkey_frame_unknown':a[8][0]=='unknown' and '__ACCEPT' in [f[1] for f in a[8][2]],
 'nointernals_poll_guarded_unavailable':a[9][:2]==['unavailable',[]],
 'nointernals_wait_guarded_unavailable':a[10][:2]==['unavailable',[]],
}
for k,v in checks.items():print(('PASS ' if v else 'FAIL ')+k)
print(json.dumps({'checks':checks,'calls':a,'scope':'Frame research only. no screen swap; sentinel guard marks no-internals unavailable, not a poll.'},indent=2))
sys.exit(not all(checks.values()))
