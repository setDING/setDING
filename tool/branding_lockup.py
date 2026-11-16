"""Builds app/branding/logo.svg and logo-dark.svg (mark + wordmark side by
side, used in the README) from the sources. Called by tool/branding.sh."""
import re
import sys

src = sys.argv[1]
mark = open(f"{src}/mark.svg").read()
mark_inner = re.search(r"<svg[^>]*>(.*)</svg>", mark, re.S).group(1)
for name, word in [("logo", "wordmark"), ("logo-dark", "wordmark-dark")]:
    w = re.sub(r"<\?xml[^>]*\?>", "", open(f"{src}/{word}.svg").read())
    vb = re.search(r'viewBox="([^"]*)"', w).group(1).split()
    width = 100 * float(vb[2]) / float(vb[3])  # wordmark 100 high
    inner = re.sub(r"<svg\b[^>]*>", "", w, count=1).rsplit("</svg>", 1)[0]
    total = 160 + 40 + width  # mark 160, gap 40
    open(f"{src}/{name}.svg", "w").write(
        f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total:.0f} 160" width="{total:.0f}" height="160">
  <!-- Generated from mark.svg and {word}.svg; see docs/development/branding.md. -->
  <svg x="0" y="0" width="160" height="160" viewBox="0 0 512 512">{mark_inner}</svg>
  <svg x="200" y="30" width="{width:.1f}" height="100" viewBox="{' '.join(vb)}">{inner}</svg>
</svg>
'''
    )
