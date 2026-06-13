import base64
from collections import deque
from io import BytesIO
from statistics import median
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from openai import OpenAI
from PIL import Image

from app.config import settings


CANVAS_SIZE = 480
PRODUCT_MAX_SIZE = 390
AI_EDIT_SIZE = 1024


def standardize_product_image_bytes(image_url: str | None) -> bytes | None:
    if not image_url:
        return None

    try:
        image_bytes = _download_image(image_url)
        if not image_bytes:
            return None
        image = Image.open(BytesIO(image_bytes)).convert("RGBA")
        standardized = _standardize_image(image)
        output = BytesIO()
        standardized.save(output, format="PNG", optimize=True)
        return output.getvalue()
    except Exception:
        return None


def clean_product_image_with_ai_bytes(
    image_url: str | None,
    *,
    product_name: str | None = None,
) -> bytes | None:
    if (
        not image_url
        or not settings.PRODUCT_IMAGE_AI_CLEANUP_ENABLED
        or not settings.OPENAI_API_KEY
    ):
        return None

    try:
        image_bytes = _download_image(image_url, timeout=10)
        if not image_bytes:
            return None

        input_png = _prepare_ai_input_png(image_bytes)
        prompt = _ai_cleanup_prompt(product_name)
        client = OpenAI(api_key=settings.OPENAI_API_KEY)
        input_file = BytesIO(input_png)
        input_file.name = "product.png"
        result = client.images.edit(
            model=settings.PRODUCT_IMAGE_AI_MODEL,
            image=input_file,
            prompt=prompt,
            size="1024x1024",
            quality="low",
        )
        encoded = result.data[0].b64_json
        if not encoded:
            return None
        edited = Image.open(BytesIO(base64.b64decode(encoded))).convert("RGBA")
        standardized = _standardize_image(edited)
        output = BytesIO()
        standardized.save(output, format="PNG", optimize=True)
        return output.getvalue()
    except Exception:
        return None


def standardize_product_image_url(image_url: str | None) -> str | None:
    if not image_url:
        return None

    standardized = standardize_product_image_bytes(image_url)
    if standardized:
        encoded = base64.b64encode(standardized).decode("ascii")
        return f"data:image/png;base64,{encoded}"

    try:
        return image_url
    except Exception:
        return None


def _download_image(image_url: str, *, timeout: int = 3) -> bytes | None:
    request = Request(
        image_url,
        headers={
            "Accept": "image/*",
            "User-Agent": "FrigoCheck/0.1 product-image-cleanup",
        },
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            content_type = response.headers.get("Content-Type", "")
            if not content_type.startswith("image/"):
                return None
            return response.read(6_000_000)
    except (HTTPError, URLError, TimeoutError):
        return None


def _prepare_ai_input_png(image_bytes: bytes) -> bytes:
    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    image.thumbnail((AI_EDIT_SIZE, AI_EDIT_SIZE), Image.Resampling.LANCZOS)

    canvas = Image.new("RGB", (AI_EDIT_SIZE, AI_EDIT_SIZE), (255, 255, 255))
    x = (AI_EDIT_SIZE - image.width) // 2
    y = (AI_EDIT_SIZE - image.height) // 2
    canvas.paste(image, (x, y))

    output = BytesIO()
    canvas.save(output, format="PNG", optimize=True)
    return output.getvalue()


def _ai_cleanup_prompt(product_name: str | None) -> str:
    name = product_name or "the food product"
    return (
        f"Create a clean ecommerce catalog image of {name}. "
        "Use the input image as the exact product/package reference. "
        "Keep the same product, packaging, logo, label layout, colors, and proportions. "
        "Remove every background object, table, hand, shadow clutter, reflections, and scenery. "
        "Place only the product centered on a pure white background. "
        "Do not invent a different product. Do not add extra text or decorations. "
        "Make it suitable for a mobile grocery inventory thumbnail."
    )


def _standardize_image(image: Image.Image) -> Image.Image:
    image = _remove_light_border_background(image)
    image = _remove_uniform_edge_background(image)
    bbox = image.getbbox()
    if bbox:
        image = image.crop(bbox)

    image.thumbnail((PRODUCT_MAX_SIZE, PRODUCT_MAX_SIZE), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (255, 255, 255, 255))
    x = (CANVAS_SIZE - image.width) // 2
    y = (CANVAS_SIZE - image.height) // 2
    canvas.alpha_composite(image, (x, y))
    return canvas.convert("RGB")


def _remove_uniform_edge_background(image: Image.Image) -> Image.Image:
    pixels = image.load()
    width, height = image.size
    if width < 8 or height < 8:
        return image

    edge_samples = []
    for x in range(width):
        edge_samples.append(pixels[x, 0][:3])
        edge_samples.append(pixels[x, height - 1][:3])
    for y in range(height):
        edge_samples.append(pixels[0, y][:3])
        edge_samples.append(pixels[width - 1, y][:3])

    background = tuple(int(median(channel)) for channel in zip(*edge_samples))
    close_edges = sum(
        1 for sample in edge_samples if _color_distance(sample, background) < 72
    )
    if close_edges / max(len(edge_samples), 1) < 0.62:
        return image

    cleaned = image.copy()
    cleaned_pixels = cleaned.load()
    visited = set()
    queue = deque()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    removed = 0
    while queue:
        x, y = queue.popleft()
        if (x, y) in visited or x < 0 or y < 0 or x >= width or y >= height:
            continue
        visited.add((x, y))

        red, green, blue, alpha = cleaned_pixels[x, y]
        if alpha == 0:
            continue
        if _color_distance((red, green, blue), background) >= 72:
            continue

        cleaned_pixels[x, y] = (255, 255, 255, 0)
        removed += 1
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))

    if removed / (width * height) > 0.88:
        return image
    return cleaned


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


def _color_distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    return abs(left[0] - right[0]) + abs(left[1] - right[1]) + abs(left[2] - right[2])
