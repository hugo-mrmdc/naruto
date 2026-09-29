import os
import subprocess
import sys
from pathlib import Path

# On garde une marge sous les 100 Mo de GitHub.
MAX_BATCH_MB = 90
MAX_FILE_MB = 95

MAX_BATCH_BYTES = MAX_BATCH_MB * 1024 * 1024
MAX_FILE_BYTES = MAX_FILE_MB * 1024 * 1024


def run(command, check=True, capture=False):
    print(">", " ".join(command))

    result = subprocess.run(
        command,
        check=check,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )

    if capture:
        return result.stdout.strip()

    return ""


def get_changed_files():
    """
    Récupère les fichiers modifiés et non suivis par Git.
    """
    output = run(
        ["git", "ls-files", "-m", "-o", "--exclude-standard", "-z"],
        capture=True
    )

    if not output:
        return []

    return [Path(p) for p in output.split("\0") if p]


def file_size(path):
    try:
        return path.stat().st_size
    except FileNotFoundError:
        return 0


def format_size(size):
    return f"{size / 1024 / 1024:.2f} MB"


def main():
    # Vérifie qu'on est bien dans un dépôt Git.
    try:
        run(["git", "rev-parse", "--is-inside-work-tree"], capture=True)
    except subprocess.CalledProcessError:
        print("Erreur : lance ce script dans ton dépôt Git.")
        sys.exit(1)

    files = get_changed_files()

    if not files:
        print("Aucun fichier à envoyer.")
        return

    print(f"\n{len(files)} fichier(s) détecté(s).\n")

    valid_files = []
    oversized_files = []

    for path in files:
        size = file_size(path)

        if size > MAX_FILE_BYTES:
            oversized_files.append((path, size))
        else:
            valid_files.append((path, size))

    if oversized_files:
        print("=" * 60)
        print("FICHIERS TROP GROS - ils ne seront pas ajoutés :")
        print("=" * 60)

        for path, size in oversized_files:
            print(f"{path} -> {format_size(size)}")

        print()

    # Trier les gros fichiers d'abord aide à remplir correctement les lots.
    valid_files.sort(key=lambda x: x[1], reverse=True)

    batches = []
    current_batch = []
    current_size = 0

    for path, size in valid_files:
        if current_batch and current_size + size > MAX_BATCH_BYTES:
            batches.append((current_batch, current_size))
            current_batch = []
            current_size = 0

        current_batch.append((path, size))
        current_size += size

    if current_batch:
        batches.append((current_batch, current_size))

    print(f"{len(batches)} push(s) seront effectués.\n")

    for index, (batch, total_size) in enumerate(batches, start=1):
        print("=" * 60)
        print(
            f"LOT {index}/{len(batches)} "
            f"- environ {format_size(total_size)}"
        )
        print("=" * 60)

        paths = []

        for path, size in batch:
            print(f"  {format_size(size):>10}  {path}")
            paths.append(str(path))

        print()

        # Ajouter uniquement les fichiers du lot courant.
        run(["git", "add", "--"] + paths)

        # Vérifie qu'il y a réellement quelque chose à commit.
        result = subprocess.run(
            ["git", "diff", "--cached", "--quiet"]
        )

        if result.returncode == 0:
            print("Rien à commit pour ce lot.")
            continue

        commit_message = f"Automatic batch {index}/{len(batches)}"

        run([
            "git",
            "commit",
            "-m",
            commit_message
        ])

        print("\nEnvoi vers GitHub...\n")

        run(["git", "push"])

        print(f"\nLot {index} envoyé avec succès.\n")

    print("=" * 60)
    print("TERMINÉ")
    print("=" * 60)

    if oversized_files:
        print("\nAttention : certains fichiers n'ont pas été envoyés :")

        for path, size in oversized_files:
            print(f"  {path} ({format_size(size)})")

        print(
            "\nCes fichiers doivent être supprimés, compressés/découpés "
            "ou envoyés avec Git LFS."
        )


if __name__ == "__main__":
    main()