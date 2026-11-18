"""从应用字符串资源导出悦听上架隐私政策和图标，避免应用内外文案漂移。"""

import html
import json
import re
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'docs/app-gallery'


def main():
    strings = json.loads((ROOT / 'entry/src/main/resources/base/element/string.json')
                         .read_text(encoding='utf-8'))['string']
    values = {item['name']: item['value'] for item in strings}
    policy = (ROOT / 'entry/src/main/ets/pages/PrivacyPage.ets').read_text(encoding='utf-8')
    # 政策版本与应用 versionName 同步（AppScope/app.json5）
    app_profile = (ROOT / 'AppScope/app.json5').read_text(encoding='utf-8')
    version_match = re.search(r'"versionName"\s*:\s*"([^"]+)"', app_profile)
    if not version_match:
        raise ValueError('AppScope/app.json5 中未找到 versionName')
    version = version_match.group(1)
    section_pattern = r"new PolicySection\('[^']+', \$r\('app.string.([^']+)'\), \[([\s\S]*?)\]\)"
    sections = []
    for title, body in re.findall(section_pattern, policy):
        paragraphs = []
        for key in re.findall(r"\$r\('app.string.([^']+)'", body):
            text = values[key].replace('%s', version)
            paragraphs.append('<p>' + html.escape(text) + '</p>')
        sections.append('<section><h2>' + html.escape(values[title]) + '</h2>\n'
                        + '\n'.join(paragraphs) + '</section>')
    if not sections:
        raise ValueError('未找到应用隐私政策章节')
    document = '''<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="悦听隐私政策：了解本地数据、书源访问、系统权限与数据管理方式。">
  <title>悦听隐私政策</title>
  <style>
    :root { color-scheme: light dark; }
    body { margin: 0; font: 16px/1.85 system-ui, sans-serif; color: #242424; background: #faf9f7; }
    main { max-width: 760px; margin: 0 auto; padding: 40px 24px 64px; }
    header { border-bottom: 1px solid #dedbd5; padding-bottom: 20px; margin-bottom: 28px; }
    h1 { font-size: 28px; margin: 0; } h2 { font-size: 20px; margin: 30px 0 12px; }
    p { margin: 12px 0; overflow-wrap: anywhere; }
    a { color: #9a4015; } footer { margin-top: 32px; }
    @media (prefers-color-scheme: dark) {
      body { color: #eae7e2; background: #191817; }
      header { border-color: #45413c; } a { color: #ffb58b; }
    }
  </style>
</head>
<body>
<main>
  <header><h1>悦听隐私政策</h1><p>更新日期：2026 年 11 月 16 日</p></header>
''' + '\n'.join(sections) + '''
</main>
</body>
</html>
'''
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / 'privacy.html').write_text(document, encoding='utf-8', newline='\n')
    shutil.copyfile(ROOT / 'AppScope/resources/base/media/app_icon_legacy.png', DEST / 'icon.png')
    metadata = json.loads((DEST / 'zh-CN.json').read_text(encoding='utf-8'))
    intro = (metadata['appName'] + '\n\n' + metadata['shortDescription'] + '\n\n'
             + metadata['fullDescription'] + '\n\n新版本说明\n' + metadata['releaseNotes'] + '\n')
    (DEST / 'introduction.txt').write_text(intro, encoding='utf-8', newline='\n')
    description = '\n'.join('<p>' + html.escape(p) + '</p>'
                            for p in metadata['fullDescription'].split('\n\n'))
    gallery = '\n'.join('<img src="' + html.escape(path, quote=True)
                        + '" alt="悦听手机应用截图 ' + str(index + 1)
                        + '" width="1280" height="2832" loading="lazy">'
                        for index, path in enumerate(metadata['screenshots']))
    landing = '''<!doctype html>
<html lang="zh-CN"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="''' + html.escape(metadata.get('shortDescription', '悦听，让聆听与阅读更从容')) + '''">
<title>''' + html.escape(metadata.get('shortDescription', '悦听，让聆听与阅读更从容')) + '''</title>
<link rel="icon" href="icon.png">
<style>
body { margin: 0; color: #292621; background: #faf8f4; font: 16px/1.85 system-ui, sans-serif; }
main { max-width: 1100px; margin: auto; padding: 48px 24px; }
header { max-width: 740px; margin-bottom: 36px; } header img { border-radius: 24px; }
h1 { font-size: 40px; margin: 12px 0 0; } h2 { font-size: 24px; }
.tagline { font-size: 24px; margin: 4px 0 20px; } a { color: #a14818; }
nav { display: flex; gap: 24px; flex-wrap: wrap; } .description { max-width: 780px; }
.description p { white-space: pre-line; } .gallery { display: grid; grid-template-columns: repeat(4, 1fr); gap: 18px; }
.gallery img { width: 100%; height: auto; border-radius: 14px; box-shadow: 0 8px 24px #30231014; }
footer { margin-top: 44px; color: #655e54; }
@media (max-width: 760px) { .gallery { grid-template-columns: repeat(2, 1fr); } }
</style></head><body><main>
<header><img src="icon.png" width="88" height="88" alt="悦听图标"><h1>悦听</h1>
<p class="tagline">''' + html.escape(metadata.get('shortDescription', '悦听，让聆听与阅读更从容')) + '''</p>
<nav><a href="privacy.html">隐私政策</a></nav></header>
<section class="description"><h2>关于悦听</h2>
''' + description + '''</section>
<section><h2>应用截图</h2><div class="gallery">
''' + gallery + '''</div></section>
<footer>悦听</footer>
</main></body></html>
'''
    (DEST / 'index.html').write_text(landing, encoding='utf-8', newline='\n')
    print(f'已导出 {len(sections)} 个隐私政策章节和上架图标至 {DEST}')


if __name__ == '__main__':
    main()
