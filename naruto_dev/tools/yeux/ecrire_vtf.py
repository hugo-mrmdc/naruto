import struct
from PIL import Image
def ecrire_vtf(img, chemin):
    """VTF 7.2 non compressé (BGR888), avec toutes les mipmaps, sans vignette."""
    img = img.convert('RGB'); w, h = img.size
    mips = []; m = img
    while True:
        mips.append(m)
        if m.size == (1, 1): break
        m = img.resize((max(1, m.size[0] // 2), max(1, m.size[1] // 2)), Image.LANCZOS)
    head = bytearray(80)
    head[0:4] = b'VTF\0'
    struct.pack_into('<II', head, 4, 7, 2)
    struct.pack_into('<I', head, 12, 80)
    struct.pack_into('<HHIHH', head, 16, w, h, 0, 1, 0)
    struct.pack_into('<3f', head, 32, 0.5, 0.5, 0.5)
    struct.pack_into('<f', head, 48, 1.0)
    struct.pack_into('<i', head, 52, 3)            # BGR888
    head[56] = len(mips)
    struct.pack_into('<i', head, 57, -1)           # pas de vignette
    head[61] = 0; head[62] = 0
    struct.pack_into('<H', head, 63, 1)            # profondeur
    data = bytearray(head)
    for m in reversed(mips):                       # de la plus petite à la plus grande
        r, g, b = m.split()
        data += Image.merge('RGB', (b, g, r)).tobytes()
    open(chemin, 'wb').write(data)
