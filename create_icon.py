#!/usr/bin/env uv run
# /// script
# dependencies = [
#   "pillow",
# ]
# ///

import os
from PIL import Image, ImageDraw, ImageFilter

# Create a Microverse alien-inspired icon
def create_microverse_icon():
    # Create sizes needed for macOS icon
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    # Create the largest size first
    size = 1024
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Define colors (alien-like green/blue from Rick and Morty)
    alien_green = (147, 250, 165)
    alien_blue = (64, 224, 208)
    dark_green = (34, 139, 34)
    light_green = (144, 238, 144)
    
    # Draw alien head shape (elongated oval)
    head_width = int(size * 0.65)
    head_height = int(size * 0.8)
    head_x = (size - head_width) // 2
    head_y = int(size * 0.1)
    
    # Main head with gradient-like effect
    for i in range(10):
        offset = i * 2
        color = tuple(int(c + (255 - c) * i / 20) for c in alien_green)
        draw.ellipse([head_x - offset, head_y - offset, 
                      head_x + head_width + offset, head_y + head_height + offset], 
                     fill=(*color, 255 - i * 10))
    
    # Main head
    draw.ellipse([head_x, head_y, head_x + head_width, head_y + head_height], 
                 fill=alien_green, outline=dark_green, width=8)
    
    # Eyes (large, characteristic alien eyes)
    eye_width = int(size * 0.22)
    eye_height = int(size * 0.26)
    eye_y = head_y + int(head_height * 0.22)
    
    # Left eye
    left_eye_x = head_x + int(head_width * 0.15)
    draw.ellipse([left_eye_x, eye_y, left_eye_x + eye_width, eye_y + eye_height],
                 fill=alien_blue, outline=dark_green, width=4)
    
    # Right eye
    right_eye_x = head_x + int(head_width * 0.63)
    draw.ellipse([right_eye_x, eye_y, right_eye_x + eye_width, eye_y + eye_height],
                 fill=alien_blue, outline=dark_green, width=4)
    
    # Eye highlights
    highlight_size = int(eye_width * 0.3)
    draw.ellipse([left_eye_x + int(eye_width * 0.15), eye_y + int(eye_height * 0.15),
                  left_eye_x + int(eye_width * 0.15) + highlight_size,
                  eye_y + int(eye_height * 0.15) + highlight_size],
                 fill=(255, 255, 255, 200))
    
    draw.ellipse([right_eye_x + int(eye_width * 0.15), eye_y + int(eye_height * 0.15),
                  right_eye_x + int(eye_width * 0.15) + highlight_size,
                  eye_y + int(eye_height * 0.15) + highlight_size],
                 fill=(255, 255, 255, 200))
    
    # Eye pupils
    pupil_size = int(eye_width * 0.4)
    draw.ellipse([left_eye_x + (eye_width - pupil_size) // 2, 
                  eye_y + (eye_height - pupil_size) // 2,
                  left_eye_x + (eye_width + pupil_size) // 2,
                  eye_y + (eye_height + pupil_size) // 2],
                 fill=(0, 0, 0))
    
    draw.ellipse([right_eye_x + (eye_width - pupil_size) // 2, 
                  eye_y + (eye_height - pupil_size) // 2,
                  right_eye_x + (eye_width + pupil_size) // 2,
                  eye_y + (eye_height + pupil_size) // 2],
                 fill=(0, 0, 0))
    
    # Nose (small dots)
    nose_y = eye_y + eye_height + int(size * 0.06)
    nose_x = head_x + head_width // 2
    dot_size = int(size * 0.025)
    draw.ellipse([nose_x - dot_size * 3, nose_y, nose_x - dot_size * 2, nose_y + dot_size], 
                 fill=dark_green)
    draw.ellipse([nose_x + dot_size * 2, nose_y, nose_x + dot_size * 3, nose_y + dot_size], 
                 fill=dark_green)
    
    # Mouth (characteristic alien smile)
    mouth_y = nose_y + int(size * 0.08)
    mouth_width = int(size * 0.2)
    mouth_x = head_x + (head_width - mouth_width) // 2
    
    # Draw smile
    draw.arc([mouth_x, mouth_y - int(size * 0.03), 
              mouth_x + mouth_width, mouth_y + int(size * 0.08)], 
             0, 180, fill=dark_green, width=8)
    
    # Add some alien-like spots/texture
    import random
    random.seed(42)  # Consistent pattern
    for i in range(20):
        spot_x = head_x + int(random.uniform(0.1, 0.9) * head_width)
        spot_y = head_y + int(random.uniform(0.15, 0.85) * head_height)
        
        # Skip if too close to eyes
        if (abs(spot_x - (left_eye_x + eye_width/2)) < eye_width and 
            abs(spot_y - (eye_y + eye_height/2)) < eye_height):
            continue
        if (abs(spot_x - (right_eye_x + eye_width/2)) < eye_width and 
            abs(spot_y - (eye_y + eye_height/2)) < eye_height):
            continue
            
        spot_size = int(size * random.uniform(0.02, 0.04))
        opacity = random.randint(80, 150)
        draw.ellipse([spot_x, spot_y, spot_x + spot_size, spot_y + spot_size],
                     fill=(*light_green, opacity))
    
    # Add subtle glow effect
    glow_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)
    glow_draw.ellipse([head_x - 20, head_y - 20, 
                       head_x + head_width + 20, head_y + head_height + 20], 
                      fill=(*alien_green, 30))
    glow_img = glow_img.filter(ImageFilter.GaussianBlur(radius=20))
    
    # Composite glow behind main image
    final_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    final_img = Image.alpha_composite(final_img, glow_img)
    final_img = Image.alpha_composite(final_img, img)
    
    # Save all sizes
    for s in sizes:
        resized = final_img.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(f'icon_{s}x{s}.png')
    
    # Also save the main 1024x1024 for iconutil
    final_img.save('AppIcon.png')
    
    print("Icon files created successfully!")
    print("Creating .icns file...")
    
    # Create iconset directory
    os.system('mkdir -p AppIcon.iconset')
    
    # Move and rename files for iconutil
    icon_mapping = {
        16: 'icon_16x16.png',
        32: 'icon_16x16@2x.png',
        32: 'icon_32x32.png',
        64: 'icon_32x32@2x.png',
        128: 'icon_128x128.png',
        256: 'icon_128x128@2x.png',
        256: 'icon_256x256.png',
        512: 'icon_256x256@2x.png',
        512: 'icon_512x512.png',
        1024: 'icon_512x512@2x.png',
    }
    
    # Copy files with proper names
    os.system('cp icon_16x16.png AppIcon.iconset/icon_16x16.png')
    os.system('cp icon_32x32.png AppIcon.iconset/icon_16x16@2x.png')
    os.system('cp icon_32x32.png AppIcon.iconset/icon_32x32.png')
    os.system('cp icon_64x64.png AppIcon.iconset/icon_32x32@2x.png')
    os.system('cp icon_128x128.png AppIcon.iconset/icon_128x128.png')
    os.system('cp icon_256x256.png AppIcon.iconset/icon_128x128@2x.png')
    os.system('cp icon_256x256.png AppIcon.iconset/icon_256x256.png')
    os.system('cp icon_512x512.png AppIcon.iconset/icon_256x256@2x.png')
    os.system('cp icon_512x512.png AppIcon.iconset/icon_512x512.png')
    os.system('cp icon_1024x1024.png AppIcon.iconset/icon_512x512@2x.png')
    
    # Create .icns file
    os.system('iconutil -c icns AppIcon.iconset -o AppIcon.icns')
    
    print("AppIcon.icns created successfully!")

if __name__ == "__main__":
    create_microverse_icon()