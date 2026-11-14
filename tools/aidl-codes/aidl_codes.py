# Own minimal DEX/ODEX reader: lists static int constants (TRANSACTION_*) of classes whose
# descriptor matches CLASS_RE, and method prototypes whose name matches NAME_RE. Read-only.
import re, struct, sys
path, class_re, name_re = sys.argv[1], re.compile(sys.argv[2]), re.compile(sys.argv[3])
raw = open(path, 'rb').read()
d = raw[struct.unpack_from('<I', raw, 8)[0]:] if raw[:4] == b'dey\n' else raw
u4 = lambda o: struct.unpack_from('<I', d, o)[0]
u2 = lambda o: struct.unpack_from('<H', d, o)[0]
def uleb(o):
    r = s = 0
    while True:
        b = d[o]; o += 1; r |= (b & 0x7f) << s; s += 7
        if not b & 0x80: return r, o
str_n, str_o = u4(56), u4(60); typ_n, typ_o = u4(64), u4(68)
pro_n, pro_o = u4(72), u4(76); fld_n, fld_o = u4(80), u4(84)
met_n, met_o = u4(88), u4(92); cls_n, cls_o = u4(96), u4(100)
def string(i):
    o = u4(str_o + 4 * i); n, o = uleb(o)
    return d[o:d.index(b'\0', o)].decode('utf-8', 'replace')
def typ(i): return string(u4(typ_o + 4 * i))
def proto(i):
    o = pro_o + 12 * i; ret = typ(u4(o + 4)); po = u4(o + 8); params = []
    if po:
        for k in range(u4(po)): params.append(typ(u2(po + 4 + 2 * k)))
    return ret, params
def field(i):
    o = fld_o + 8 * i; return typ(u2(o)), typ(u2(o + 2)), string(u4(o + 4))
def method(i):
    o = met_o + 8 * i; return typ(u2(o)), proto(u2(o + 2)), string(u4(o + 4))
def enc_value(o):
    h = d[o]; vt, va = h & 0x1f, h >> 5; o += 1
    if vt in (0x00, 0x02, 0x03, 0x04, 0x06, 0x10, 0x11, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b):
        n = va + 1; b = d[o:o + n]; o += n
        if vt in (0x00, 0x02, 0x04, 0x06):
            v = int.from_bytes(b, 'little', signed=True)
        else:
            v = int.from_bytes(b, 'little', signed=False)
        return (vt, v), o
    if vt == 0x1c:  # array
        n, o = uleb(o); vals = []
        for _ in range(n): v, o = enc_value(o); vals.append(v)
        return (vt, vals), o
    if vt == 0x1d:  # annotation
        _, o = uleb(o); n, o = uleb(o)
        for _ in range(n): _, o = uleb(o); _, o = enc_value(o)
        return (vt, None), o
    if vt in (0x1e, 0x1f): return (vt, va if vt == 0x1f else None), o
    raise ValueError('value type %#x' % vt)
print('# file', path)
for c in range(cls_n):
    o = cls_o + 32 * c; name = typ(u4(o)); cdo, svo = u4(o + 24), u4(o + 28)
    if not class_re.search(name) or not cdo: continue
    nsf, p = uleb(cdo); nif, p = uleb(p); ndm, p = uleb(p); nvm, p = uleb(p)
    fidx = 0; names = []
    for _ in range(nsf):
        diff, p = uleb(p); _, p = uleb(p); fidx += diff; names.append(field(fidx)[2])
    vals = []
    if svo:
        n, q = uleb(svo)
        for _ in range(n): v, q = enc_value(q); vals.append(v)
    print('## class', name, 'static fields', nsf, 'with values', len(vals))
    for nm, v in zip(names, vals):
        if name_re.search(nm): print('  ', nm, '=', v[1])
seen = set()
for m in range(met_n):
    cls, (ret, params), nm = method(m)
    if class_re.search(cls) and name_re.search(nm) and (cls, nm, tuple(params)) not in seen:
        seen.add((cls, nm, tuple(params))); print('  method', cls, nm, '(' + ', '.join(params) + ') ->', ret)
