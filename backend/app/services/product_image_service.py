import base64
from io import BytesIO
from statistics import median
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from PIL import Image


CANVAS_SIZE = 480
PRODUCT_MAX_SIZE = 390


def standardize_product_image_url(image_url: str | None) -> str | None:
    if not image_url:
        return None

    try:
        image_bytes = _download_image(image_url)
        if not image_bytes:
            return image_url
        image = Image.open(BytesIO(image_bytes)).convert("RGBA")
        standardized = _standardize_image(image)
        output = BytesIO()
        standardized.save(output, format="PNG", optimize=True)
        encoded = base64.b64encode(output.getvalue()).decode("ascii")
        return f"data:image/png;base64,{encoded}"
    except Exception:
        return image_url


def _download_image(image_url: str) -> bytes | None:
    request = Request(
        image_url,
        headers={
            "Accept": "image/*",
            "User-Agent": "FrigoCheck/0.1 product-image-cleanup",
        },
    )
    try:
        with urlopen(request, timeout=3) as response:
            content_type = response.headers.get("Content-Type", "")
            if not content_type.startswith("image/"):
                return None
            return response.read(6_000_000)
    except (HTTPError, URLError, TimeoutError):
        return None


def _standardize_image(image: Image.Image) -> Image.Image:
    image = _remove_light_border_background(image)
    bbox = image.getbbox()
    if bbox:
        image = image.crop(bbox)

    image.thumbnail((PRODUCT_MAX_SIZE, PRODUCT_MAX_SIZE), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (255, 255, 255, 255))
    x = (CANVAS_SIZE - image.width) // 2
    y = (CANVAS_SIZE - image.height) // 2
    canvas.alpha_composite(image, (x, y))
    return canvas.convert("RGB")


def _remove_light_border_background(image: Image.Image) -> Image.Image:
    pixels = image.load()
    width, height = image.size
    samples = []

    for x in range(width):
        samples.append(pixels[x, 0][:3])
        samples.append(pixels[x, height - 1][:3])
    for y in range(height):
        samples.append(pixels[0, y][:3])
        samples.append(pixels[width - 1, y][:3])

    background = tuple(int(median(channel)) for channel in zip(*samples))
    if sum(background) / 3 < 185:
        return image

    cleaned = image.copy()
    cleaned_pixels = cleaned.load()
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = cleaned_pixels[x, y]
            distance = (
                abs(red - background[0])
                + abs(green - background[1])
                + abs(blue - background[2])
            )
            if distance < 58 and red > 165 and green > 165 and blue > 165:
                cleaned_pixels[x, y] = (255, 255, 255, 0)

    return cleaned
