import struct, sys

def parse(path):
    d = open(path, 'rb').read()
    p = d.index(b'\0') + 1
    header = d[:p-1].decode().strip()
    ver = int(header.split('binary ')[1].split()[0])
    def i32():
        nonlocal p; v = struct.unpack_from('<i', d, p)[0]; p += 4; return v
    def cstr():
        nonlocal p; e = d.index(b'\0', p); s = d[p:e].decode('latin1'); p = e + 1; return s
    def i16():
        nonlocal p; v = struct.unpack_from('<h', d, p)[0]; p += 2; return v
    def sidx():
        return strings[i16()] if ver >= 2 else cstr()
    strings = []
    if ver >= 2:
        n = i16()
        strings = [cstr() for _ in range(n)]
    ne = i32()
    elems = []
    for _ in range(ne):
        t = sidx(); name = sidx() if ver >= 4 else cstr()
        guid = d[p:p+16].hex(); p += 16
        elems.append({'type': t, 'name': name, 'guid': guid, 'attrs': {}})
    def val(t):
        nonlocal p
        if t == 1:
            v = i32()
            if v == -2: return ('ext', cstr())
            return ('elem', v)
        if t == 2: return i32()
        if t == 3: v = struct.unpack_from('<f', d, p)[0]; p += 4; return round(v, 4)
        if t == 4: v = d[p]; p += 1; return bool(v)
        if t == 5: return cstr() if ver < 4 else sidx()
        if t == 6: n = i32(); v = d[p:p+n]; p += n; return v.hex()
        if t == 7: return i32() / 10000
        if t == 8: v = tuple(d[p:p+4]); p += 4; return v
        sizes = {9: 2, 10: 3, 11: 4, 12: 3, 13: 4, 14: 16}
        if t in sizes:
            n = sizes[t]; v = struct.unpack_from('<%df' % n, d, p); p += 4 * n
            return tuple(round(x, 4) for x in v)
        if 15 <= t <= 28:
            n = i32()
            sub = t - 14
            if sub == 5:
                return [cstr() for _ in range(n)]
            return [val(sub) for _ in range(n)]
        raise ValueError('bad type %d at %d' % (t, p))
    for e in elems:
        na = i32()
        for _ in range(na):
            an = sidx(); t = d[p]; p += 1
            e['attrs'][an] = (t, val(t))
    return header, elems, p, len(d)

if __name__ == '__main__':
    header, elems, end, size = parse(sys.argv[1])
    print(header, '| elements:', len(elems), '| parsed', end, '/', size)
    for i, e in enumerate(elems):
        print('\n[%d] %s "%s"' % (i, e['type'], e['name']))
        for k, (t, v) in e['attrs'].items():
            if isinstance(v, tuple) and len(v) == 2 and v[0] == 'elem':
                v = '-> [%d] %s' % (v[1], elems[v[1]]['name'] if v[1] >= 0 else 'NULL')
            elif isinstance(v, list) and v and isinstance(v[0], tuple) and v[0][0] == 'elem':
                v = ['[%d] %s' % (x[1], elems[x[1]]['name']) for x in v]
            print('   %s = %r' % (k, v))
