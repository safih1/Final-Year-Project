import os
import csv
import requests
import yt_dlp

# ---- CONFIG ----
FFMPEG_PATH = r"C:\ffmpeg-8.0-essentials_build\bin"  # 👈 set your ffmpeg path here
OUTPUT_DIR = "grunt_clips"

# ---- HELPERS ----
def download_file(url, filename):
    if not os.path.exists(filename):
        print(f"[INFO] {filename} not found, downloading...")
        r = requests.get(url, stream=True)
        with open(filename, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"[OK] Downloaded {filename}")

def load_class_map(label_csv):
    class_map = {}
    with open(label_csv, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            class_map[row['display_name']] = row['mid']
    return class_map

def extract_segments(segment_csv, target_mid):
    matches = []
    with open(segment_csv, newline='', encoding='utf-8') as f:
        reader = csv.reader(f, delimiter=',')
        next(reader)  # skip header
        for row in reader:
            try:
                yt_id, start, end, labels = row[0], float(row[1]), float(row[2]), row[3]
                if target_mid in labels:
                    matches.append((yt_id, start, end))
            except ValueError:
                continue
    return matches

def download_audio_from_video(video_id, start, end, output_folder=OUTPUT_DIR):
    os.makedirs(output_folder, exist_ok=True)
    url = f"https://www.youtube.com/watch?v={video_id}"
    output_template = f"{output_folder}/{video_id}_{int(start)}_{int(end)}.%(ext)s"

    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': output_template,
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'wav',
        }],
        'download_sections': {'*': f"{start}-{end}"},
        'ffmpeg_location': FFMPEG_PATH,  # 👈 force ffmpeg
        'quiet': False,
        'noplaylist': True,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
        print(f"[OK] Saved: {output_template}")
    except Exception as e:
        print(f"[ERROR] Failed for {video_id}: {e}")

def extract_for_class(segment_csv, class_csv, target_class, output_folder=OUTPUT_DIR):
    # download metadata files if missing
    download_file("https://research.google.com/audioset/download/balanced_train_segments.csv",
                  "balanced_train_segments.csv")
    download_file("https://research.google.com/audioset/download/unbalanced_train_segments.csv",
                  "unbalanced_train_segments.csv")

    class_map = load_class_map(class_csv)
    if target_class not in class_map:
        print(f"[ERROR] Class '{target_class}' not found in {class_csv}")
        return
    target_mid = class_map[target_class]

    print(f"[INFO] Target class: {target_class} (MID={target_mid})")
    matches = extract_segments(segment_csv, target_mid)
    print(f"[INFO] Found {len(matches)} matching clips.")

    for yt_id, start, end in matches:
        download_audio_from_video(yt_id, start, end, output_folder)

# ---- MAIN ----
if __name__ == "__main__":
    extract_for_class("eval_segments.csv", "class_labels_indices.csv", "Grunt", output_folder=OUTPUT_DIR)
