"""Render the board before/after diagram with fixed Korean text and layout.

Requires Pillow and Windows Malgun Gothic fonts. Run from the repository root.
"""
from pathlib import Path
import argparse
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--lang', choices=('ko', 'ja'), default='ko')
LANG = parser.parse_args().lang
TRANSLATIONS = {
    '게시판의 비동기 상태 처리': '掲示板の非同期状態管理',
    '기존 처리': '以前の処理',
    '변경 후 처리': '変更後の処理',
    '게시판 진입': '掲示板を開く',
    '전체 게시글\n실시간 구독': '全投稿を\nリアルタイム購読',
    '받은 목록 표시': '取得した一覧を表示',
    '변경된 구독 결과로\n자동 갱신': '購読結果の変更で\n自動更新',
    '오류 발생 시\n목록 대신 오류 문구 표시': 'エラー時は一覧の代わりに\nエラーメッセージを表示',
    '최대 20개 조회 후 표시': '最大20件を取得して表示',
    '새로고침 ·\n상세 화면 복귀 시\n재조회': '更新操作・\n詳細画面からの復帰で\n再取得',
    '스크롤 시\n다음 20개 조회': 'スクロール時に\n次の20件を取得',
    '조회 결과': '取得結果',
    '기존 목록에 추가': '既存の一覧に追加',
    '기존 목록 유지 ·\n재시도 제공': '既存の一覧を維持・\n再試行を提供',
    '성공': '成功',
    '실패': '失敗',
}
SCALE = 2
W, H = 1800, 1480
image = Image.new('RGB', (W * SCALE, H * SCALE), '#FFFDF9')
draw = ImageDraw.Draw(image)
FONT = Path('C:/Windows/Fonts/YuGothM.ttc' if LANG == 'ja' else 'C:/Windows/Fonts/malgun.ttf')
BOLD = Path('C:/Windows/Fonts/YuGothB.ttc' if LANG == 'ja' else 'C:/Windows/Fonts/malgunbd.ttf')
INK, MUTED, CORAL = '#32201C', '#796B65', '#FD5D69'


def coords(values):
    return tuple(round(v * SCALE) for v in values)


def text(center, value, size=30, color=INK, bold=False):
    if LANG == 'ja':
        value = TRANSLATIONS[value]
    font = ImageFont.truetype(str(BOLD if bold else FONT), size * SCALE)
    box = draw.multiline_textbbox((0, 0), value, font=font, spacing=10 * SCALE, align='center')
    x, y = center
    draw.multiline_text(
        (round(x * SCALE - (box[2] + box[0]) / 2),
         round(y * SCALE - (box[3] + box[1]) / 2)),
        value, font=font, fill=color, spacing=10 * SCALE, align='center',
    )


def rect(box, fill, outline, radius=20, width=2):
    draw.rounded_rectangle(coords(box), radius=radius * SCALE, fill=fill,
                           outline=outline, width=width * SCALE)


def node(box, label, fill='#FFFFFF', outline='#E5DCD6', size=29):
    rect(box, fill, outline)
    text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), label, size)


def arrow(points, color=MUTED):
    draw.line([coords(p) for p in points], fill=color, width=3 * SCALE,
              joint='curve')
    x, y = points[-1]
    px, py = points[-2]
    angle = math.atan2(y - py, x - px)
    head = [(x, y)] + [
        (x - 15 * math.cos(angle + delta), y - 15 * math.sin(angle + delta))
        for delta in (-0.45, 0.45)
    ]
    draw.polygon([coords(p) for p in head], fill=color)


text((900, 66), '게시판의 비동기 상태 처리', 45, bold=True)
rect((45, 150, 800, 1420), '#F7F3EF', '#E6DCD4', radius=28)
rect((840, 150, 1755, 1420), '#FFF0ED', '#FFC6C9', radius=28)
text((422, 200), '기존 처리', 36, bold=True)
text((1297, 200), '변경 후 처리', 36, color=CORAL, bold=True)

# Original: stream delivers a complete list; error replaces the list.
node((190, 270, 690, 365), '게시판 진입')
node((190, 450, 690, 575), '전체 게시글\n실시간 구독')
node((190, 710, 690, 810), '받은 목록 표시')
node((190, 915, 690, 1040), '변경된 구독 결과로\n자동 갱신')
node((190, 1170, 690, 1300), '오류 발생 시\n목록 대신 오류 문구 표시', fill='#FFF5F3', outline='#E5B5AC', size=28)
arrow([(440, 365), (440, 450)])
arrow([(440, 575), (440, 710)])
arrow([(440, 810), (440, 915)])
arrow([(190, 510), (110, 510), (110, 1235), (190, 1235)])

# Current: initial page branches to explicit refresh or the next page.
node((1040, 270, 1560, 365), '게시판 진입')
node((1040, 450, 1560, 575), '최대 20개 조회 후 표시')
node((890, 700, 1240, 835), '새로고침 ·\n상세 화면 복귀 시\n재조회', size=26)
node((1330, 700, 1690, 835), '스크롤 시\n다음 20개 조회', size=28)
arrow([(1300, 365), (1300, 450)])
arrow([(1170, 575), (1170, 635), (1065, 635), (1065, 700)])
arrow([(1430, 575), (1430, 635), (1510, 635), (1510, 700)])
draw.polygon([coords(p) for p in [(1510, 910), (1630, 1010), (1510, 1110), (1390, 1010)]],
             fill='#FFFFFF', outline='#FD5D69', width=2 * SCALE)
text((1510, 1010), '조회 결과', 28)
arrow([(1510, 835), (1510, 910)])
node((890, 1230, 1240, 1350), '기존 목록에 추가', size=27)
node((1320, 1230, 1700, 1350), '기존 목록 유지 ·\n재시도 제공', fill='#FFFFFF', outline='#FD5D69', size=28)
arrow([(1450, 1060), (1450, 1165), (1065, 1165), (1065, 1230)])
arrow([(1570, 1060), (1570, 1175), (1510, 1175), (1510, 1230)])
rect((1020, 1177, 1110, 1220), '#FFF0ED', '#FFF0ED', radius=5, width=1)
text((1065, 1198), '성공', 23, bold=True)
rect((1465, 1177, 1555, 1220), '#FFF0ED', '#FFF0ED', radius=5, width=1)
text((1510, 1198), '실패', 23, color=CORAL, bold=True)

suffix = '-ja' if LANG == 'ja' else ''
output = ROOT / f'docs/images/board-async-state{suffix}.png'
image.save(output, optimize=True)
print(f'{output.name}: {image.width}x{image.height}')
