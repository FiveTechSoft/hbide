"""Historical Q58 reproducer. Resolved narrow ASCII+caret case now lives in
 tests/test_gcc_caret_column_pty.py; missing/ambiguous caret keeps fallback.
Run that acceptance probe rather than retaining an intentionally failing copy.
"""
import pathlib, runpy
runpy.run_path(str(pathlib.Path(__file__).resolve().parents[1]/'test_gcc_caret_column_pty.py'),run_name='__main__')
