"""Dump embedded UnrealScript source (TextBuffer objects) from a UE1 .u package.

Usage: python -I dump_uscript.py <package.u> <out_dir>
"""
import os
import struct
import sys


class Reader:
    def __init__(self, data, pos=0):
        self.data = data
        self.pos = pos

    def u8(self):
        v = self.data[self.pos]
        self.pos += 1
        return v

    def i32(self):
        v = struct.unpack_from("<i", self.data, self.pos)[0]
        self.pos += 4
        return v

    def u32(self):
        v = struct.unpack_from("<I", self.data, self.pos)[0]
        self.pos += 4
        return v

    def index(self):
        # UE1 compact index
        b0 = self.u8()
        neg = b0 & 0x80
        val = b0 & 0x3F
        if b0 & 0x40:
            shift = 6
            while True:
                b = self.u8()
                val |= (b & 0x7F) << shift
                shift += 7
                if not b & 0x80:
                    break
        return -val if neg else val

    def name_str(self, ver):
        if ver >= 64:
            n = self.index()
            s = self.data[self.pos:self.pos + n]
            self.pos += n
            return s.rstrip(b"\0").decode("latin-1")
        end = self.data.index(b"\0", self.pos)
        s = self.data[self.pos:end]
        self.pos = end + 1
        return s.decode("latin-1")

    def fstring(self):
        n = self.index()
        if n < 0:
            raw = self.data[self.pos:self.pos - n * 2]
            self.pos += -n * 2
            return raw.decode("utf-16-le").rstrip("\0")
        raw = self.data[self.pos:self.pos + n]
        self.pos += n
        return raw.rstrip(b"\0").decode("latin-1")


def main(path, out_dir):
    data = open(path, "rb").read()
    r = Reader(data)
    if r.u32() != 0x9E2A83C1:
        sys.exit("not an Unreal package")
    ver = r.u32() & 0xFFFF
    r.u32()  # flags
    name_count, name_off = r.u32(), r.u32()
    export_count, export_off = r.u32(), r.u32()
    import_count, import_off = r.u32(), r.u32()

    names = []
    r.pos = name_off
    for _ in range(name_count):
        names.append(r.name_str(ver))
        r.u32()

    imports = []
    r.pos = import_off
    for _ in range(import_count):
        r.index(); cls = r.index(); r.i32(); obj = r.index()
        imports.append((names[cls], names[obj]))

    exports = []
    r.pos = export_off
    for _ in range(export_count):
        cls = r.index(); r.index(); outer = r.i32(); name = r.index(); r.u32()
        size = r.index()
        off = r.index() if size > 0 else 0
        exports.append((cls, outer, names[name], size, off))

    def class_name(ref):
        if ref < 0:
            return imports[-ref - 1][1]
        if ref > 0:
            return exports[ref - 1][2]
        return "Class"

    os.makedirs(out_dir, exist_ok=True)
    count = 0
    for cls, outer, name, size, off in exports:
        if class_name(cls) != "TextBuffer" or name != "ScriptText" or size <= 0:
            continue
        owner = exports[outer - 1][2] if outer > 0 else "unknown"
        br = Reader(data, off)
        # TextBuffer has no tagged properties when it has no state; skip the 'None' terminator.
        if names[br.index()] != "None":
            print("unexpected properties on", owner)
            continue
        br.i32(); br.i32()  # Pos, Top
        text = br.fstring()
        with open(os.path.join(out_dir, owner + ".uc"), "w", encoding="utf-8", newline="") as f:
            f.write(text)
        count += 1
    print(f"package version {ver}: wrote {count} classes to {out_dir}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
