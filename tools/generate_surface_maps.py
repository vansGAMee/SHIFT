"""Derive restrained, tileable relief from SHIFT's existing original textures."""
from pathlib import Path
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1] / 'assets' / 'textures'
for name, strength in [('concrete', 2.0), ('floor', 3.0), ('metal', 3.5), ('green', 1.4)]:
    height = np.asarray(Image.open(root / f'{name}.png').convert('L'), dtype=float) / 255
    # Wrapped smoothing preserves seams and prevents sparkling pixel-sized normals.
    height = (height * 4 + np.roll(height, 1, 0) + np.roll(height, -1, 0)
              + np.roll(height, 1, 1) + np.roll(height, -1, 1)) / 8
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    normal = np.stack((-dx, dy, np.ones_like(height)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    Image.fromarray(np.uint8(np.clip(normal * 0.5 + 0.5, 0, 1) * 255)).save(root / f'{name}_normal.png')
print('Generated 4 seamless surface normal maps.')
