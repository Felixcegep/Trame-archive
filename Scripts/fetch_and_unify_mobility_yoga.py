import urllib.request
import json
import re
import os
import pandas as pd
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(PROJECT_ROOT, "GymTracker/Core/Data")
MOBILITY_SEED_FILE = os.path.join(PROJECT_ROOT, "GymTracker/Core/Features/Mobility/MobilitySeedData.swift")
OUTPUT_DOC_DIR = os.path.join(PROJECT_ROOT, "Documentation/Resources/Mobility_and_Yoga")
OUTPUT_APP_DIR = os.path.join(PROJECT_ROOT, "GymTracker/Resources/Mobility")
ROOT_EXPORT_DIR = os.path.join(PROJECT_ROOT, "exports")

def normalize_key(name):
    if not name: return ""
    return re.sub(r'[^a-z0-9]', '', name.lower())

def make_seed_key(name, namespace="movement"):
    folded = name.lower()
    slug = ""
    for ch in folded:
        if ch.isalnum(): slug += ch
        elif ch.isspace(): slug += "-"
        elif ch == "-": slug += "--"
        elif ch == "+": slug += "-plus-"
        elif ch == "/": slug += "-slash-"
        else: slug += f"-u{ord(ch):x}-"
    slug = slug.strip("-")
    while "--" in slug and "---" in slug:
        slug = slug.replace("---", "--")
    return f"{namespace}.{slug}"

def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))

def parse_trame_mobility_seeds():
    if not os.path.exists(MOBILITY_SEED_FILE):
        return []
    with open(MOBILITY_SEED_FILE, "r", encoding="utf-8") as f:
        content = f.read()
    
    pattern = r'\(\s*"([^"]+)"\s*,\s*"([^"]*)"\s*,\s*\.([a-zA-Z]+)\s*,\s*(nil|\d+)\s*,\s*(nil|\d+)\s*,\s*"([^"]+)"\s*\)'
    matches = re.findall(pattern, content)
    items = []
    for name, instructions, tracking, duration, reps, family in matches:
        items.append({
            "name": name,
            "instructions": instructions,
            "tracking_type": "Duration" if tracking == "duration" else "Repetitions",
            "default_duration_seconds": int(duration) if duration != "nil" else None,
            "default_repetitions": int(reps) if reps != "nil" else None,
            "family_name": family,
            "sources": ["trame"]
        })
    return items

def style_excel(filepath, sheet_name="Data", custom_widths=None):
    wb = openpyxl.load_workbook(filepath)
    ws = wb.active
    ws.title = sheet_name
    ws.views.sheetView[0].showGridLines = True

    header_fill = PatternFill(start_color="1F2937", end_color="1F2937", fill_type="solid")
    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    header_align = Alignment(horizontal="center", vertical="center", wrap_text=True)
    even_fill = PatternFill(start_color="F9FAFB", end_color="F9FAFB", fill_type="solid")
    odd_fill = PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")
    thin_border = Border(
        left=Side(style='thin', color='E5E7EB'), right=Side(style='thin', color='E5E7EB'),
        top=Side(style='thin', color='E5E7EB'), bottom=Side(style='thin', color='E5E7EB')
    )

    num_cols = ws.max_column
    ws.row_dimensions[1].height = 28
    for col_idx in range(1, num_cols + 1):
        cell = ws.cell(row=1, column=col_idx)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = header_align
        cell.border = thin_border

    data_font = Font(name="Calibri", size=10)
    for r_idx in range(2, ws.max_row + 1):
        ws.row_dimensions[r_idx].height = 24
        fill = even_fill if r_idx % 2 == 0 else odd_fill
        for col_idx in range(1, num_cols + 1):
            cell = ws.cell(row=r_idx, column=col_idx)
            cell.fill = fill
            cell.font = data_font
            cell.border = thin_border
            cell.alignment = Alignment(vertical="top", wrap_text=True)

    for col_idx in range(1, num_cols + 1):
        col_letter = get_column_letter(col_idx)
        col_name = str(ws.cell(row=1, column=col_idx).value or "")
        if custom_widths and col_name in custom_widths:
            ws.column_dimensions[col_letter].width = custom_widths[col_name]
        elif col_name in ["Instructions", "Description", "Benefits", "Steps", "Tips", "English Instructions", "English Description", "Pose Description"]:
            ws.column_dimensions[col_letter].width = 45
        elif "URL" in col_name or "Image" in col_name or "SVG" in col_name or "PNG" in col_name:
            ws.column_dimensions[col_letter].width = 30
        elif "Name" in col_name or "Key" in col_name or "Muscles" in col_name:
            ws.column_dimensions[col_letter].width = 25
        else:
            max_len = len(col_name)
            for cell in ws[col_letter]:
                val_str = str(cell.value or "")
                if len(val_str) > max_len:
                    max_len = min(len(val_str), 30)
            ws.column_dimensions[col_letter].width = max(max_len + 4, 12)

    wb.save(filepath)

def main():
    print("=========================================================")
    print("🚀 Ingesting, Comparing & Unifying Yoga and Mobility")
    print("=========================================================")
    os.makedirs(OUTPUT_DOC_DIR, exist_ok=True)
    os.makedirs(OUTPUT_APP_DIR, exist_ok=True)
    os.makedirs(ROOT_EXPORT_DIR, exist_ok=True)

    # 1. Parse Current Trame Mobility
    trame_mobility = parse_trame_mobility_seeds()
    print(f"Trame App Current State: {len(trame_mobility)} seeded mobility/stretching definitions.")

    # 2. Fetch Yoga API
    print("Fetching Yoga Poses from https://yoga-api-nzy4.onrender.com/v1/poses ...")
    yoga_raw = fetch_json("https://yoga-api-nzy4.onrender.com/v1/poses")
    print(f"Loaded {len(yoga_raw)} Yoga Poses.")

    yoga_rows = []
    for pose in yoga_raw:
        yoga_rows.append({
            "ID": pose.get("id"),
            "English Name": pose.get("english_name"),
            "Sanskrit Name": pose.get("sanskrit_name"),
            "Sanskrit Adapted": pose.get("sanskrit_name_adapted"),
            "Translation / Meaning": pose.get("translation_name"),
            "Pose Description": pose.get("pose_description"),
            "Benefits": pose.get("pose_benefits"),
            "Category": "Yoga / Flexibility",
            "Tracking Type": "Duration",
            "Default Duration (s)": 30,
            "SVG URL": pose.get("url_svg"),
            "PNG URL": pose.get("url_png"),
            "Alt SVG URL": pose.get("url_svg_alt")
        })

    df_yoga = pd.DataFrame(yoga_rows)
    yoga_json_path = os.path.join(OUTPUT_DOC_DIR, "yoga_poses_all.json")
    yoga_csv_path = os.path.join(OUTPUT_DOC_DIR, "yoga_poses_all.csv")
    yoga_xlsx_path = os.path.join(OUTPUT_DOC_DIR, "yoga_poses_all.xlsx")

    with open(yoga_json_path, "w", encoding="utf-8") as f:
        json.dump(yoga_raw, f, indent=2, ensure_ascii=False)
    with open(os.path.join(OUTPUT_APP_DIR, "yoga_poses_all.json"), "w", encoding="utf-8") as f:
        json.dump(yoga_raw, f, indent=2, ensure_ascii=False)
    with open(os.path.join(ROOT_EXPORT_DIR, "yoga_poses_all.json"), "w", encoding="utf-8") as f:
        json.dump(yoga_raw, f, indent=2, ensure_ascii=False)

    df_yoga.to_csv(yoga_csv_path, index=False, encoding="utf-8-sig")
    df_yoga.to_csv(os.path.join(ROOT_EXPORT_DIR, "yoga_poses_all.csv"), index=False, encoding="utf-8-sig")
    df_yoga.to_excel(yoga_xlsx_path, index=False)
    df_yoga.to_excel(os.path.join(ROOT_EXPORT_DIR, "yoga_poses_all.xlsx"), index=False)
    style_excel(yoga_xlsx_path, "Yoga Poses")
    style_excel(os.path.join(ROOT_EXPORT_DIR, "yoga_poses_all.xlsx"), "Yoga Poses")
    print(f"✅ Exported Yoga datasets to {yoga_xlsx_path}, {yoga_csv_path}, {yoga_json_path}")

    # 3. Fetch Free Exercise DB (and isolate stretching)
    print("Fetching Free Exercise DB from https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json ...")
    free_raw = fetch_json("https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json")
    print(f"Loaded {len(free_raw)} exercises from Free Exercise DB.")

    free_stretches = [x for x in free_raw if x.get("category") == "stretching"]
    print(f"Filtered {len(free_stretches)} Mobility / Stretching exercises.")

    stretch_rows = []
    for s in free_stretches:
        imgs = [f"https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{img}" for img in (s.get("images") or [])]
        steps_text = "\n".join([f"{i+1}. {st}" for i, st in enumerate(s.get("instructions") or [])])
        equip_str = str(s.get("equipment") or "body only").capitalize()
        cat_str = str(s.get("category") or "stretching").capitalize()
        lvl_str = str(s.get("level") or "beginner").capitalize()

        stretch_rows.append({
            "ID": s.get("id"),
            "Name": s.get("name"),
            "Category": cat_str,
            "Difficulty Level": lvl_str,
            "Equipment": equip_str,
            "Force Type": s.get("force") or "",
            "Mechanic": s.get("mechanic") or "",
            "Primary Muscles": ", ".join(s.get("primaryMuscles") or []),
            "Secondary Muscles": ", ".join(s.get("secondaryMuscles") or []),
            "Instructions": steps_text,
            "Image 1 URL": imgs[0] if len(imgs) > 0 else "",
            "Image 2 URL": imgs[1] if len(imgs) > 1 else "",
            "Source": "free-exercise-db"
        })

    df_stretch = pd.DataFrame(stretch_rows)
    stretch_json_path = os.path.join(OUTPUT_DOC_DIR, "free_exercise_db_stretching.json")
    stretch_csv_path = os.path.join(OUTPUT_DOC_DIR, "free_exercise_db_stretching.csv")
    stretch_xlsx_path = os.path.join(OUTPUT_DOC_DIR, "free_exercise_db_stretching.xlsx")

    with open(stretch_json_path, "w", encoding="utf-8") as f:
        json.dump(free_stretches, f, indent=2, ensure_ascii=False)
    with open(os.path.join(OUTPUT_APP_DIR, "free_exercise_db_stretching.json"), "w", encoding="utf-8") as f:
        json.dump(free_stretches, f, indent=2, ensure_ascii=False)
    with open(os.path.join(ROOT_EXPORT_DIR, "free_exercise_db_stretching.json"), "w", encoding="utf-8") as f:
        json.dump(free_stretches, f, indent=2, ensure_ascii=False)

    df_stretch.to_csv(stretch_csv_path, index=False, encoding="utf-8-sig")
    df_stretch.to_csv(os.path.join(ROOT_EXPORT_DIR, "free_exercise_db_stretching.csv"), index=False, encoding="utf-8-sig")
    df_stretch.to_excel(stretch_xlsx_path, index=False)
    df_stretch.to_excel(os.path.join(ROOT_EXPORT_DIR, "free_exercise_db_stretching.xlsx"), index=False)
    style_excel(stretch_xlsx_path, "Stretching Exercises")
    style_excel(os.path.join(ROOT_EXPORT_DIR, "free_exercise_db_stretching.xlsx"), "Stretching Exercises")
    print(f"✅ Exported Stretching datasets to {stretch_xlsx_path}, {stretch_csv_path}, {stretch_json_path}")

    # 5. Build Master Movement, Mobility & Yoga Unified Database & Comparison
    print("\n--- Generating Master Movement, Mobility & Yoga Unified Database ---")
    unified_movements = {}

    for tm in trame_mobility:
        norm = normalize_key(tm["name"])
        unified_movements[norm] = {
            "name": tm["name"],
            "seed_key": make_seed_key(tm["name"], "mobility"),
            "sources": ["trame"],
            "category": "Mobility",
            "family_name": tm["family_name"],
            "tracking_type": tm["tracking_type"],
            "default_duration_seconds": tm["default_duration_seconds"],
            "default_repetitions": tm["default_repetitions"],
            "difficulty": "All Levels",
            "equipment": "Bodyweight / Mat",
            "primary_muscles": [],
            "secondary_muscles": [],
            "instructions": tm["instructions"],
            "benefits": "",
            "sanskrit_name": "",
            "met": 2.5,
            "image_url": "",
            "svg_url": ""
        }

    for p in yoga_raw:
        ename = p.get("english_name", "").strip()
        norm = normalize_key(ename)
        if norm in unified_movements:
            entry = unified_movements[norm]
            if "yoga-api" not in entry["sources"]:
                entry["sources"].append("yoga-api")
            entry["sanskrit_name"] = p.get("sanskrit_name_adapted") or p.get("sanskrit_name") or ""
            entry["benefits"] = p.get("pose_benefits") or ""
            entry["svg_url"] = p.get("url_svg") or ""
            entry["image_url"] = p.get("url_png") or ""
            if not entry["instructions"]:
                entry["instructions"] = p.get("pose_description") or ""
        else:
            unified_movements[norm] = {
                "name": f"Yoga: {ename}",
                "seed_key": make_seed_key(ename, "yoga"),
                "sources": ["yoga-api"],
                "category": "Yoga",
                "family_name": "Yoga & Balance",
                "tracking_type": "Duration",
                "default_duration_seconds": 30,
                "default_repetitions": None,
                "difficulty": "All Levels",
                "equipment": "Yoga Mat / Bodyweight",
                "primary_muscles": [],
                "secondary_muscles": [],
                "instructions": p.get("pose_description") or "",
                "benefits": p.get("pose_benefits") or "",
                "sanskrit_name": p.get("sanskrit_name_adapted") or p.get("sanskrit_name") or "",
                "met": 2.5,
                "image_url": p.get("url_png") or "",
                "svg_url": p.get("url_svg") or ""
            }

    for s in free_stretches:
        sname = s.get("name", "").strip()
        norm = normalize_key(sname)
        imgs = [f"https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{img}" for img in (s.get("images") or [])]
        inst = "\n".join([f"{i+1}. {st}" for i, st in enumerate(s.get("instructions") or [])])

        if norm in unified_movements:
            entry = unified_movements[norm]
            if "free-exercise-db" not in entry["sources"]:
                entry["sources"].append("free-exercise-db")
            if not entry["image_url"] and imgs:
                entry["image_url"] = imgs[0]
            if not entry["instructions"]:
                entry["instructions"] = inst
            entry["primary_muscles"] = list(set(entry["primary_muscles"] + (s.get("primaryMuscles") or [])))
            entry["secondary_muscles"] = list(set(entry["secondary_muscles"] + (s.get("secondaryMuscles") or [])))
        else:
            p_muscles = s.get("primaryMuscles") or []
            fam_prefix = p_muscles[0].capitalize() if p_muscles else "Full Body"
            unified_movements[norm] = {
                "name": sname,
                "seed_key": make_seed_key(sname, "stretch"),
                "sources": ["free-exercise-db"],
                "category": "Stretching",
                "family_name": f"{fam_prefix} Stretch",
                "tracking_type": "Duration",
                "default_duration_seconds": 30,
                "default_repetitions": None,
                "difficulty": str(s.get("level") or "beginner").capitalize(),
                "equipment": str(s.get("equipment") or "body only").capitalize(),
                "primary_muscles": p_muscles,
                "secondary_muscles": s.get("secondaryMuscles") or [],
                "instructions": inst,
                "benefits": "",
                "sanskrit_name": "",
                "met": 2.5,
                "image_url": imgs[0] if imgs else "",
                "svg_url": ""
            }

    master_list = list(unified_movements.values())
    master_list.sort(key=lambda x: x["name"].lower())

    both_count = sum(1 for x in master_list if len(x["sources"]) > 1)
    print(f"\n--- Master Mobility & Yoga Summary ---")
    print(f"Total Unified Mobility/Yoga Entries: {len(master_list)}")
    print(f"Multi-source Matched Entries: {both_count}")

    master_rows = []
    for m in master_list:
        master_rows.append({
            "Movement Name": m["name"],
            "Seed Key": m["seed_key"],
            "Sources": ", ".join(m["sources"]),
            "Category": m["category"],
            "Family / Routine Group": m["family_name"],
            "Tracking Type": m["tracking_type"],
            "Default Duration (s)": m["default_duration_seconds"] if m["default_duration_seconds"] is not None else "",
            "Default Reps": m["default_repetitions"] if m["default_repetitions"] is not None else "",
            "Difficulty": m["difficulty"],
            "Equipment": m["equipment"],
            "Primary Muscles": ", ".join(m["primary_muscles"]),
            "Secondary Muscles": ", ".join(m["secondary_muscles"]),
            "Sanskrit Name": m["sanskrit_name"],
            "MET": m["met"] if m["met"] is not None else "",
            "Benefits / Description": m["benefits"],
            "Instructions": m["instructions"],
            "Image URL": m["image_url"],
            "SVG URL": m["svg_url"]
        })

    df_master = pd.DataFrame(master_rows)
    master_json_path = os.path.join(OUTPUT_DOC_DIR, "master_mobility_and_yoga_unified.json")
    master_csv_path = os.path.join(OUTPUT_DOC_DIR, "master_mobility_and_yoga_unified.csv")
    master_xlsx_path = os.path.join(OUTPUT_DOC_DIR, "master_mobility_and_yoga_unified.xlsx")

    with open(master_json_path, "w", encoding="utf-8") as f:
        json.dump(master_list, f, indent=2, ensure_ascii=False)
    with open(os.path.join(OUTPUT_APP_DIR, "master_mobility_and_yoga_unified.json"), "w", encoding="utf-8") as f:
        json.dump(master_list, f, indent=2, ensure_ascii=False)
    with open(os.path.join(ROOT_EXPORT_DIR, "master_mobility_and_yoga_unified.json"), "w", encoding="utf-8") as f:
        json.dump(master_list, f, indent=2, ensure_ascii=False)

    df_master.to_csv(master_csv_path, index=False, encoding="utf-8-sig")
    df_master.to_csv(os.path.join(ROOT_EXPORT_DIR, "master_mobility_and_yoga_unified.csv"), index=False, encoding="utf-8-sig")
    df_master.to_excel(master_xlsx_path, index=False)
    df_master.to_excel(os.path.join(ROOT_EXPORT_DIR, "master_mobility_and_yoga_unified.xlsx"), index=False)
    style_excel(master_xlsx_path, "Master Mobility & Yoga")
    style_excel(os.path.join(ROOT_EXPORT_DIR, "master_mobility_and_yoga_unified.xlsx"), "Master Mobility & Yoga")
    print(f"✅ Exported Master Unified Database to {master_xlsx_path}, {master_csv_path}, {master_json_path}")

if __name__ == "__main__":
    main()
