"""生成 1024×1024 默认/播放态分层应用图标。

运行：python scripts/generate_app_icon.py

依赖 Pillow。默认图标为闭眼微笑猫，播放备用图标为厌世猫；
前景为完整构图，背景取源图边缘不透明色铺满，不添加额外圆角蒙版。
同步写入 AppScope 与 entry 两套 media。
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
IDLE_SOURCE = ROOT / '10_小猫·绘本风·闭眼微笑.png'
PLAYING_SOURCE = ROOT / '12_小猫·绘本风·厌世表情.png'
MEDIA_DIRS = (
    ROOT / 'AppScope/resources/base/media',
    ROOT / 'entry/src/main/resources/base/media',
)


def load_source(path: Path) -> Image.Image:
    if not path.is_file():
        raise FileNotFoundError(f'missing icon source: {path}')
    image = Image.open(path).convert('RGBA')
    if image.size == (SIZE, SIZE):
        return image
    width, height = image.size
    scale = max(SIZE / width, SIZE / height)
    resized = image.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - SIZE) // 2
    top = (resized.height - SIZE) // 2
    return resized.crop((left, top, left + SIZE, top + SIZE))


def solid_background(source: Image.Image) -> Image.Image:
    samples: list[tuple[int, int, int, int]] = []
    for x, y in (
        (8, 8), (SIZE - 9, 8), (8, SIZE - 9), (SIZE - 9, SIZE - 9),
        (SIZE // 2, 8), (SIZE // 2, SIZE - 9), (8, SIZE // 2), (SIZE - 9, SIZE // 2),
    ):
        pixel = source.getpixel((x, y))
        if pixel[3] > 200:
            samples.append(pixel)
    if not samples:
        samples = [
            source.getpixel((0, 0)),
            source.getpixel((SIZE - 1, 0)),
            source.getpixel((0, SIZE - 1)),
            source.getpixel((SIZE - 1, SIZE - 1)),
        ]
    color = tuple(sum(channel[i] for channel in samples) // len(samples) for i in range(3)) + (255,)
    return Image.new('RGBA', (SIZE, SIZE), color)


def write_icon(prefix: str, source_path: Path) -> None:
    foreground = load_source(source_path)
    background = solid_background(foreground)
    composed = Image.alpha_composite(background, foreground).convert('RGB')
    background_rgb = background.convert('RGB')
    layered = {
        'background': background_rgb,
        'foreground': composed,
        'legacy': composed,
    }
    json_body = (
        '{\n  "layered-image": {\n'
        f'    "background": "$media:{prefix}_background",\n'
        f'    "foreground": "$media:{prefix}_foreground"\n'
        '  }\n}\n'
    )
    for media_dir in MEDIA_DIRS:
        media_dir.mkdir(parents=True, exist_ok=True)
        for layer, bitmap in layered.items():
            path = media_dir / f'{prefix}_{layer}.png'
            bitmap.save(path, optimize=True)
            print(f'{path.relative_to(ROOT)}: {bitmap.width}x{bitmap.height}')
        (media_dir / f'{prefix}.json').write_text(json_body, encoding='utf-8')


def main() -> None:
    write_icon('app_icon', IDLE_SOURCE)
    write_icon('app_icon_playing', PLAYING_SOURCE)


if __name__ == '__main__':
    main()
