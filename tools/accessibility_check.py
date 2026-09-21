"""Offline palette simulation; pip install daltonlens==0.1.5 pillow==12.3.0."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from daltonlens import simulate
root=Path(__file__).resolve().parents[1]/"verification"
root.mkdir(exist_ok=True)
colors=np.array([[[197,138,128],[199,174,120]]],dtype=np.uint8)
rows=[("Original",colors)]
simulator=simulate.Simulator_Brettel1997()
for name, deficiency in [("Protanopia",simulate.Deficiency.PROTAN),("Deuteranopia",simulate.Deficiency.DEUTAN),("Tritanopia",simulate.Deficiency.TRITAN)]:
 rows.append((name,simulator.simulate_cvd(colors,deficiency,severity=1.0)))
canvas=Image.new("RGB",(840,420),(24,24,24));d=ImageDraw.Draw(canvas)
font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",18)
report=["# Palette simulation", "", "DaltonLens 0.1.5, Brettel 1997, severity 1.0; sRGB input/output.","https://github.com/DaltonLens/DaltonLens-Python", "", "| Simulation | Incident | Warning |", "|---|---|---|"]
for i,(name,pixels) in enumerate(rows):
 vals=[tuple(map(int,x)) for x in pixels[0]]
 codes=["#"+"".join(f"{v:02X}" for v in rgb) for rgb in vals]
 report.append(f"| {name} | {codes[0]} | {codes[1]} |")
 y=20+i*100
 d.text((15,y+20),name,font=font,fill="white")
 for j,rgb in enumerate(vals):
  x=190+j*315
  d.rectangle((x,y,x+295,y+75),fill=rgb)
  d.text((x+8,y+8),["INCIDENT","WARNING"][j],font=font,fill="black")
  d.text((x+8,y+38),codes[j],font=font,fill="black")
canvas.save(root/"color-simulation.png")
report += ["", "The simulated pairs are numerically distinct, but this is not a perceptual pass/fail threshold.","Protan/deutan reduce the hue distinction to similar muted yellow/brown tones; do not rely on color.","Tritan maps both colors to pink tones; the difference is largely lightness. Do not rely on that distinction either.","All severities now have explicit INCIDENT / WARNING / STATUS wording, including merged summaries.","Context and controls use one neutral color: no encoded severity. Hold progress uses fill length next to HOLD text.","No information is removed by mapping the palette to a single neutral color; contrast over game scenes is still unverified."]
(root/"accessibility.md").write_text("\n".join(report))
print("\n".join(report))
