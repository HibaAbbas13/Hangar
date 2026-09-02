from PIL import Image, ImageDraw, ImageFilter

S = 4096          # supersample, downsampled to 1024 at the end
OUT = 1024

VOID   = (13, 12, 10)
PANEL  = (34, 31, 27)
BRASS  = (190, 150, 101)
BRASS_HI = (222, 194, 143)

# ---- ground: the app's own void, warmed toward the top-right like FDScreenBackground
base = Image.new("RGB", (S, S), VOID)
glow = Image.new("L", (S, S), 0)
gd = ImageDraw.Draw(glow)
gd.ellipse([int(S*0.30), int(-S*0.28), int(S*1.45), int(S*0.85)], fill=70)
glow = glow.filter(ImageFilter.GaussianBlur(S // 9))
base = Image.composite(Image.new("RGB", (S, S), PANEL), base, glow)

# ---- brass, lit from the top edge
brass = Image.new("RGB", (S, S), BRASS)
bd = ImageDraw.Draw(brass)
for y in range(S):
    t = y / S
    bd.line([(0, y), (S, y)], fill=(
        int(BRASS_HI[0] + (BRASS[0] - BRASS_HI[0]) * t),
        int(BRASS_HI[1] + (BRASS[1] - BRASS_HI[1]) * t),
        int(BRASS_HI[2] + (BRASS[2] - BRASS_HI[2]) * t),
    ))

def arch(d, cx, half_w, top_y, bottom_y, fill):
    """A hangar opening: semicircular head over straight jambs."""
    r = half_w
    shoulder = top_y + r
    d.pieslice([cx - r, top_y, cx + r, top_y + 2 * r], 180, 360, fill=fill)
    d.rectangle([cx - r, shoulder, cx + r, bottom_y], fill=fill)

mask = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(mask)

CX = S // 2
# A hangar reads wider than tall — squat arch, short jambs.
TOP, BOTTOM = int(S * 0.232), int(S * 0.682)   # nudged up: a round head reads low when mathematically centred
OUTER, WALL = int(S * 0.290), int(S * 0.080)

arch(md, CX, OUTER, TOP, BOTTOM, 255)                                  # the shell
arch(md, CX, OUTER - WALL, TOP + WALL, BOTTOM + 10, 0)                 # hollow it out

# the deck it stands on
plinth_h = int(S * 0.046)
py = BOTTOM + int(S * 0.026)          # the arch stands on it, not above it
md.rounded_rectangle(
    [CX - int(S * 0.345), py, CX + int(S * 0.345), py + plinth_h],
    radius=plinth_h // 2, fill=255,
)

icon = Image.composite(brass, base, mask)
icon = icon.resize((OUT, OUT), Image.LANCZOS).convert("RGB")   # RGB: no alpha channel
icon.save("/Users/apple/Hangar/Hangar/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
print("written")
