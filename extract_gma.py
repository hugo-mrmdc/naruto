#!/usr/bin/env python3
"""
Extracteur de fichiers .gma (Garry's Mod Addon)
Usage: python extract_gma.py fichier.gma [dossier_sortie]
"""

import struct
import sys
import os

def read_string(f):
    """Lit une chaîne null-terminated."""
    chars = []
    while True:
        c = f.read(1)
        if c == b'\x00' or c == b'':
            break
        chars.append(c)
    return b''.join(chars).decode('utf-8', errors='replace')

def extract_gma(gma_path, output_dir=None):
    if output_dir is None:
        output_dir = os.path.splitext(gma_path)[0]

    print(f"Extraction de : {gma_path}")
    print(f"Destination   : {output_dir}")

    with open(gma_path, 'rb') as f:
        # Vérif magic bytes
        magic = f.read(4)
        if magic != b'GMAD':
            print("ERREUR : Ce n'est pas un fichier GMA valide.")
            return False

        version   = struct.unpack('B', f.read(1))[0]
        steamid   = struct.unpack('<Q', f.read(8))[0]
        timestamp = struct.unpack('<Q', f.read(8))[0]

        # Required content (ignoré)
        if version > 1:
            while True:
                s = read_string(f)
                if s == '':
                    break

        name        = read_string(f)
        description = read_string(f)
        author      = read_string(f)
        addon_ver   = struct.unpack('<i', f.read(4))[0]

        print(f"Addon : {name} | Auteur : {author}")

        # Liste des fichiers
        files = []
        while True:
            file_num = struct.unpack('<I', f.read(4))[0]
            if file_num == 0:
                break
            file_name = read_string(f)
            file_size = struct.unpack('<q', f.read(8))[0]
            file_crc  = struct.unpack('<I', f.read(4))[0]
            files.append({'name': file_name, 'size': file_size, 'crc': file_crc})

        print(f"{len(files)} fichiers trouvés.")

        # Extraction des données
        os.makedirs(output_dir, exist_ok=True)
        for i, entry in enumerate(files):
            dest = os.path.join(output_dir, entry['name'].replace('/', os.sep))
            os.makedirs(os.path.dirname(dest), exist_ok=True)

            chunk_size = 1024 * 1024  # 1 MB
            remaining  = entry['size']
            with open(dest, 'wb') as out:
                while remaining > 0:
                    data = f.read(min(chunk_size, remaining))
                    if not data:
                        break
                    out.write(data)
                    remaining -= len(data)

            print(f"[{i+1}/{len(files)}] {entry['name']} ({entry['size'] // 1024} KB)")

    print("\nExtraction terminée !")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage : python extract_gma.py fichier.gma [dossier_sortie]")
        sys.exit(1)

    gma_path   = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) >= 3 else None
    extract_gma(gma_path, output_dir)
