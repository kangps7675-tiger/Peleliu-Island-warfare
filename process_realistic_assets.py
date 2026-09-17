import os
import glob
import numpy as np
from PIL import Image

artifact_dir = r"C:\Users\kangp\.gemini\antigravity-ide\brain\7c29db46-3616-47bf-b4c0-57267ce09c29"
target_dir = r"c:\Users\kangp\OneDrive\문서\뱀\assets\sprites"
os.makedirs(target_dir, exist_ok=True)

def clean_cutout(img_path, threshold=22):
    img = Image.open(img_path).convert("RGBA")
    data = np.array(img)
    
    corner_pixels = [data[0, 0][:3], data[0, -1][:3], data[-1, 0][:3], data[-1, -1][:3]]
    bg_color = np.mean(corner_pixels, axis=0)
    
    dist = np.linalg.norm(data[:, :, :3] - bg_color, axis=2)
    alpha = np.clip((dist - threshold) / 16.0, 0.0, 1.0) * 255
    data[:, :, 3] = alpha.astype(np.uint8)
    
    res = Image.fromarray(data)
    bbox = res.getbbox()
    if bbox:
        res = res.crop(bbox)
    return res

# 1. Corsair Clean (미 해군 F4U 콜세어 - 날개 위 폭탄 제거된 버전)
matches = glob.glob(os.path.join(artifact_dir, "corsair_clean_*.jpg"))
if matches:
    img = clean_cutout(sorted(matches)[-1], threshold=24)
    w, h = img.size
    img = img.crop((0, int(h * 0.12), w, h))
    img = img.rotate(42, expand=True, resample=Image.Resampling.BICUBIC)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img = img.resize((380, 380), Image.Resampling.LANCZOS)
    img.save(os.path.join(target_dir, "corsair_bomber.png"), "PNG")
    print("Saved corsair_bomber.png")

# 2. Zero Clean (A6M 제로센 - 폭탄 없는 순수 전투기)
matches = glob.glob(os.path.join(artifact_dir, "zero_clean_*.jpg"))
if matches:
    img = clean_cutout(sorted(matches)[-1], threshold=20)
    img = img.rotate(-132, expand=True, resample=Image.Resampling.BICUBIC)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img = img.resize((220, 220), Image.Resampling.LANCZOS)
    img.save(os.path.join(target_dir, "kamikaze_plane.png"), "PNG")
    print("Saved kamikaze_plane.png (clean A6M)")

# 3. Aerial Bomb (500lb AN-M64 고폭 항공 폭탄)
matches = glob.glob(os.path.join(artifact_dir, "aerial_bomb_*.jpg"))
if matches:
    img = clean_cutout(sorted(matches)[-1], threshold=22)
    img = img.rotate(-90, expand=True, resample=Image.Resampling.BICUBIC)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img = img.resize((96, 160), Image.Resampling.LANCZOS)
    img.save(os.path.join(target_dir, "aerial_bomb.png"), "PNG")
    print("Saved aerial_bomb.png")

# 4. Battleship Yamato (전함 야마토 - 460mm 3연장 주포탑 디테일)
matches = glob.glob(os.path.join(artifact_dir, "yamato_hull_*.jpg"))
if matches:
    img = clean_cutout(sorted(matches)[-1], threshold=28)
    img = img.rotate(-90, expand=True, resample=Image.Resampling.BICUBIC)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    aspect = w / h
    img = img.resize((720, int(720 / aspect)), Image.Resampling.LANCZOS)
    img.save(os.path.join(target_dir, "battleship_yamato.png"), "PNG")
    print("Saved battleship_yamato.png")

# 5. Cave Fortress Gun (움루브로골 동굴 요새포 보스)
matches = glob.glob(os.path.join(artifact_dir, "cave_fortress_gun_*.jpg"))
if matches:
    img = clean_cutout(sorted(matches)[-1], threshold=20)
    img = img.resize((360, 360), Image.Resampling.LANCZOS)
    img.save(os.path.join(target_dir, "cave_fortress_gun.png"), "PNG")
    print("Saved cave_fortress_gun.png")

# 6. WW2 Wooden Ammo Crate (기존 판타지 보석 대체)
crate_img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
from PIL import ImageDraw
draw = ImageDraw.Draw(crate_img)
draw.rectangle([10, 14, 54, 50], fill=(62, 70, 48, 255), outline=(32, 38, 26, 255), width=2)
draw.line([10, 26, 54, 26], fill=(42, 48, 34, 255), width=2)
draw.line([10, 38, 54, 38], fill=(42, 48, 34, 255), width=2)
draw.rectangle([8, 12, 16, 52], fill=(45, 48, 40, 255))
draw.rectangle([48, 12, 56, 52], fill=(45, 48, 40, 255))
draw.rectangle([22, 28, 42, 36], fill=(180, 160, 80, 220))
crate_img.save(os.path.join(target_dir, "ammo_crate.png"), "PNG")
print("Saved ammo_crate.png")

print("All realistic assets generated and saved!")
