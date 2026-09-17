import os
import glob
from PIL import Image

artifact_dir = r"C:\Users\kangp\.gemini\antigravity-ide\brain\7c29db46-3616-47bf-b4c0-57267ce09c29"
target_dir = r"c:\Users\kangp\OneDrive\문서\뱀\assets\sprites"
os.makedirs(target_dir, exist_ok=True)

mappings = [
    ("iron_serpent_head", "snake_head.png", -90),     # 90도 회전하여 오른쪽(0도) 전방
    ("flak_segment_topdown", "snake_segment.png", -90), # 90도 회전
    ("zero_kamikaze_plane", "kamikaze_plane.png", -90), # 90도 회전
    ("b29_superfortress_topdown", "b29_bomber.png", 0),  # 아래쪽으로 비행
    ("corsair_fighter_bomber", "corsair_bomber.png", 0),
    ("japanese_bunker_outpost", "japanese_bunker.png", 0),
    ("chiha_tank_topdown", "chiha_tank.png", 180),     # 포신이 오른쪽으로 향하도록 180도
]

def make_transparent(img, threshold=25):
    img = img.convert("RGBA")
    datas = img.getdata()
    new_data = []
    for item in datas:
        # 순수 검은색 근처 배경을 투명으로
        r, g, b, a = item
        if r < threshold and g < threshold and b < threshold:
            new_data.append((r, g, b, 0))
        elif r < threshold + 20 and g < threshold + 20 and b < threshold + 20:
            # 가장자리 부드러운 안티앨리어싱 알파 블렌딩
            max_val = max(r, g, b)
            alpha = int(((max_val - threshold) / 20.0) * 255)
            new_data.append((r, g, b, alpha))
        else:
            new_data.append((r, g, b, 255))
    img.putdata(new_data)
    return img

for prefix, out_name, rot in mappings:
    pattern = os.path.join(artifact_dir, f"{prefix}_*.jpg")
    matches = glob.glob(pattern)
    if matches:
        latest = sorted(matches)[-1]
        print(f"Processing: {latest} -> {out_name}")
        img = Image.open(latest)
        img = make_transparent(img, threshold=18)
        if rot != 0:
            img = img.rotate(rot, expand=True, resample=Image.Resampling.BICUBIC)
        # 512x512 또는 256x256 최적 해상도로 리사이즈
        if "bomber" in out_name:
            img = img.resize((380, 380), Image.Resampling.LANCZOS)
        elif "tank" in out_name or "head" in out_name or "bunker" in out_name:
            img = img.resize((256, 256), Image.Resampling.LANCZOS)
        else:
            img = img.resize((192, 192), Image.Resampling.LANCZOS)
            
        out_path = os.path.join(target_dir, out_name)
        img.save(out_path, "PNG")
        print(f"Saved: {out_path} ({img.size})")

print("All sprites successfully processed!")
