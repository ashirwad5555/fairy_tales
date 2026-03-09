"""
One-time script to upload:
  1. stories.json  → MongoDB (categories, books, pages collections)
  2. JPEG images   → MongoDB GridFS (each image stored as a binary file)

Run:
    python upload_all.py
"""

import json
import os
import sys
from pathlib import Path
from pymongo import MongoClient
from pymongo.errors import DuplicateKeyError
import gridfs
import certifi
from dotenv import load_dotenv

load_dotenv()

# ── Config ─────────────────────────────────────────────────────
MONGO_URI   = os.getenv("MONGO_URI")
DB_NAME     = "fairytales_db"

# Paths (relative to this script)
BASE_DIR    = Path(__file__).parent.parent          # fary_tales/
JSON_PATH   = BASE_DIR / "assets" / "data" / "stories.json"
IMAGES_ROOT = BASE_DIR / "assets" / "images"       # images/stories/aaji_meera/*.jpg


# ══════════════════════════════════════════════════════════════
# CONNECT
# ══════════════════════════════════════════════════════════════
def connect():
    print(f"🔌 Connecting to MongoDB Atlas …")
    client = MongoClient(MONGO_URI, tlsCAFile=certifi.where())
    db     = client[DB_NAME]
    # Quick ping
    client.admin.command("ping")
    print(f"✅ Connected → database: '{DB_NAME}'\n")
    return client, db


# ══════════════════════════════════════════════════════════════
# 1.  UPLOAD JSON DATA
# ══════════════════════════════════════════════════════════════
def upload_json(db):
    print("=" * 50)
    print("📖  Uploading stories.json …")
    print("=" * 50)

    with open(JSON_PATH, encoding="utf-8") as f:
        data = json.load(f)

    cat_count  = 0
    book_count = 0
    page_count = 0

    for cat in data.get("categories", []):
        books_payload = cat.pop("books", [])

        # ── Insert category ──────────────────────────────────
        if not db.categories.find_one({"name": cat["name"]}):
            db.categories.insert_one(cat)
            cat_count += 1
            print(f"  ✔ Category  : {cat['name']}")
        else:
            print(f"  ⚠  Category already exists (skipped): {cat['name']}")

        # ── Insert books ─────────────────────────────────────
        for book in books_payload:
            pages_payload = book.pop("pages", [])
            book["categoryName"] = cat["name"]

            if not db.books.find_one({"title": book["title"]}):
                db.books.insert_one(book)
                book_count += 1
                print(f"     ✔ Book  : {book['title']}")
            else:
                print(f"     ⚠  Book already exists (skipped): {book['title']}")

            # ── Insert pages ─────────────────────────────────
            for idx, page in enumerate(pages_payload):
                page["bookTitle"]  = book["title"]
                page["pageIndex"]  = idx

                if not db.pages.find_one({
                    "bookTitle": book["title"],
                    "pageIndex": idx
                }):
                    db.pages.insert_one(page)
                    page_count += 1
                    print(f"        ✔ Page {idx + 1}: {page.get('text', '')[:50]}…")

    print()
    print(f"  📊 Summary:")
    print(f"     Categories : {cat_count}")
    print(f"     Books      : {book_count}")
    print(f"     Pages      : {page_count}")
    print()


# ══════════════════════════════════════════════════════════════
# 2.  UPLOAD IMAGES → GridFS
# ══════════════════════════════════════════════════════════════
def upload_images(client, db):
    print("=" * 50)
    print("🖼️   Uploading images to GridFS …")
    print("=" * 50)

    fs = gridfs.GridFS(db, collection="story_images")

    # Supported extensions
    extensions = {".jpg", ".jpeg", ".png", ".webp"}

    # Walk every subfolder under assets/images/
    image_files = [
        p for p in IMAGES_ROOT.rglob("*")
        if p.is_file() and p.suffix.lower() in extensions
    ]

    if not image_files:
        print("  ⚠  No images found under:", IMAGES_ROOT)
        return

    uploaded = 0
    skipped  = 0

    for img_path in sorted(image_files):
        # Store with a logical asset path as filename
        # e.g. "assets/images/stories/aaji_meera/img1.jpg"
        relative = img_path.relative_to(BASE_DIR).as_posix()

        # Skip if already uploaded (match by filename field)
        existing = db.story_images.files.find_one({"filename": relative})
        if existing:
            print(f"  ⚠  Already in GridFS (skipped): {relative}")
            skipped += 1
            continue

        with open(img_path, "rb") as f:
            fs.put(
                f,
                filename   = relative,
                contentType= "image/jpeg",
                metadata   = {
                    "story":     img_path.parent.name,   # "aaji_meera"
                    "imageName": img_path.name,           # "img1.jpg"
                }
            )

        print(f"  ✔ Uploaded: {relative}")
        uploaded += 1

    print()
    print(f"  📊 Summary:")
    print(f"     Uploaded : {uploaded}")
    print(f"     Skipped  : {skipped}")
    print()


# ══════════════════════════════════════════════════════════════
# 3.  VERIFY  — print what landed in MongoDB
# ══════════════════════════════════════════════════════════════
def verify(db):
    print("=" * 50)
    print("🔍  Verification")
    print("=" * 50)
    print(f"  categories   : {db.categories.count_documents({})} documents")
    print(f"  books        : {db.books.count_documents({})} documents")
    print(f"  pages        : {db.pages.count_documents({})} documents")
    print(f"  images(GridFS): {db.story_images.files.count_documents({})} files")
    print()

    print("  📂 Categories in DB:")
    for c in db.categories.find({}, {"_id": 0, "name": 1}):
        print(f"     - {c['name']}")

    print("\n  📚 Books in DB:")
    for b in db.books.find({}, {"_id": 0, "title": 1, "storyType": 1, "categoryName": 1}):
        print(f"     - [{b.get('storyType','text'):5}]  {b['title']}  → {b.get('categoryName','')}")

    print("\n  🖼️  Images in GridFS:")
    for f in db.story_images.files.find({}, {"filename": 1, "_id": 0}):
        print(f"     - {f['filename']}")

    print()


# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    if not MONGO_URI:
        print("❌  MONGO_URI not set. Check your .env file.")
        sys.exit(1)

    client, db = connect()

    upload_json(db)
    upload_images(client, db)
    verify(db)

    client.close()
    print("🎉  All done! MongoDB Atlas is ready.")