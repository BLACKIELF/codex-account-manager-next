from PIL import Image
import os

src_path = "Resources/codexU-icon.png"
output_dir = "windows/apps/codexu-tauri/src-tauri/icons"
os.makedirs(output_dir, exist_ok=True)

src = Image.open(src_path).convert("RGBA")

# Make it square by centering on a transparent / white background.
size = max(src.size)
square = Image.new("RGBA", (size, size), (255, 255, 255, 0))
offset = ((size - src.width) // 2, (size - src.height) // 2)
square.paste(src, offset, src)

for out_size in [32, 128, 256]:
    img = square.resize((out_size, out_size), Image.LANCZOS)
    if out_size == 256:
        img.save(os.path.join(output_dir, "icon.png"))
        img_2x = img
    elif out_size == 128:
        img.save(os.path.join(output_dir, "128x128.png"))
        img_2x = square.resize((256, 256), Image.LANCZOS)
        img_2x.save(os.path.join(output_dir, "128x128@2x.png"))
    elif out_size == 32:
        img.save(os.path.join(output_dir, "32x32.png"))

# Generate ICO with multiple sizes.
img_256 = Image.open(os.path.join(output_dir, "icon.png"))
img_256.save(
    os.path.join(output_dir, "icon.ico"),
    format="ICO",
    sizes=[(32, 32), (128, 128), (256, 256)],
)

print("Icons generated from macOS source.")
