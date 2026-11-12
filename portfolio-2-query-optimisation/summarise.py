# summarise.py - turns explain_before.txt / explain_after.txt into explain_summary.txt
import re, sys
def parse(path):
    res, q = {}, None
    for line in open(path):
        m = re.match(r'--- (Q\d)', line)
        if m: q = m.group(1); res[q] = {'ms': None, 'scans': []}; continue
        if q is None: continue
        m = re.search(r'Execution Time: ([\d.]+) ms', line)
        if m: res[q]['ms'] = float(m.group(1))
        m = re.search(r'(Seq Scan|Index Only Scan|(?<!Bitmap )Index Scan|Bitmap Heap Scan) (?:using \S+ )?on (\w+)', line)
        if m:
            kind = {'Seq Scan': 'Seq', 'Index Only Scan': 'IdxOnly', 'Index Scan': 'Idx', 'Bitmap Heap Scan': 'Bitmap'}[m.group(1)]
            res[q]['scans'].append(f'{m.group(2)}:{kind}')
    return res
b, a = parse(sys.argv[1]), parse(sys.argv[2])
out = ['P2 summary - EXPLAIN ANALYZE execution time (ms) and how each table was read', '']
out.append(f"{'Query':<5} {'Before ms':>10} {'After ms':>10} {'Speed-up':>9}  Tables read AFTER (table:scan type)")
for q in sorted(b):
    bm, am = b[q]['ms'], a.get(q, {}).get('ms')
    sp = f'{bm/am:.1f}x' if bm and am else '-'
    out.append(f"{q:<5} {bm:>10.2f} {am:>10.2f} {sp:>9}  {' '.join(a[q]['scans'])}")
out += ['', 'Before-plan scans:'] + [f"  {q}: {' '.join(b[q]['scans'])}" for q in sorted(b)]
out += ['', 'Note: Q2 and Q5 are full-history aggregates kept on purpose; a Seq Scan is the correct plan there.',
        'Small differences where the plan did not change are run-to-run noise.']
open('explain_summary.txt', 'w').write('\n'.join(out) + '\n')
print('\n'.join(out))
