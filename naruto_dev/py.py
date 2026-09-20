import os

root_dir = r"C:\Program Files (x86)\Steam\steamapps\workshop\content\4000"

found_paths = []

for root, dirs, files in os.walk(root_dir):
    for file in files:
        if "salamandre" in file.lower():
            full_path = os.path.join(root, file)
            found_paths.append(full_path)

# Affichage
if found_paths:
    print("Fichiers contenant 'poison' trouvés :\n")
    for path in found_paths:
        print(path)
else:
    print("❌ Aucun fichier contenant 'poison' trouvé")

print(f"\nTotal trouvé : {len(found_paths)}")
