"""Pure validation helpers for the MacroLens scanner.

This module deliberately uses only the Python standard library so its rules can
be tested without installing FastAPI or the DeepSeek client. The API validates
every model response through `validate_analysis` before returning it to the app.
"""

from __future__ import annotations

import math
import re
from typing import Any

FOOD_ONLY_MESSAGE = (
    "Nouri scans food only. Try a clear photo showing edible food or a drink."
)
INVALID_ESTIMATE_MESSAGE = (
    "Nouri returned an invalid estimate. Try another food photo or add the food manually."
)
INVALID_NUTRITION_MESSAGE = (
    "Nouri returned invalid nutrition values. Try another food photo or add the food manually."
)
UNREADABLE_IMAGE_MESSAGE = "Upload a readable JPEG, PNG, GIF, or WebP photo."

MIN_PORTION_G = 1.0
MAX_PORTION_G = 5000.0
MAX_IMAGE_BYTES = 15 * 1024 * 1024


class AnalysisError(Exception):
    """A validation failure that maps directly to an HTTP error."""

    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


def _finite_number(value: Any) -> bool:
    # bool is a subclass of int; JSON true/false is not a nutrition number.
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _number(value: Any) -> float | None:
    if not _finite_number(value):
        return None
    return float(value)


def _clean_text(value: Any, max_length: int) -> str:
    if not isinstance(value, str):
        return ""
    cleaned = re.sub(r"\s+", " ", value).strip()
    cleaned = "".join(ch for ch in cleaned if ch.isprintable())
    return cleaned[:max_length]


def sniff_image_type(data: bytes) -> str | None:
    """Identifies supported image signatures without trusting the upload MIME."""
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith(b"GIF87a") or data.startswith(b"GIF89a"):
        return "image/gif"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None


def validate_image(data: bytes) -> str:
    """Validates image size/signature and returns the detected MIME type.

    DeepSeek supports JPEG, PNG, GIF, and WebP and detects the format from the
    file content. HEIC/HEIF is intentionally rejected with a clear message
    rather than being forwarded as an unsupported format.
    """
    if not data:
        raise AnalysisError(
            400, "The uploaded photo is empty. Choose a photo and try again."
        )
    if len(data) > MAX_IMAGE_BYTES:
        raise AnalysisError(413, "Image must be 15 MB or smaller.")
    detected = sniff_image_type(data)
    if detected is None:
        raise AnalysisError(415, UNREADABLE_IMAGE_MESSAGE)
    return detected


def validate_analysis(payload: Any) -> dict[str, Any]:
    """Returns a clean, structured response or raises AnalysisError.

    Only one loggable food is returned. Portion bounds are widened when needed
    so a scan never implies that a photo produced a measured weight.
    """
    if not isinstance(payload, dict):
        raise AnalysisError(502, INVALID_ESTIMATE_MESSAGE)

    if payload.get("food_detected") is not True:
        raise AnalysisError(422, FOOD_ONLY_MESSAGE)

    items = payload.get("items")
    if not isinstance(items, list) or not items:
        raise AnalysisError(422, FOOD_ONLY_MESSAGE)

    item = items[0]
    if not isinstance(item, dict):
        raise AnalysisError(502, INVALID_ESTIMATE_MESSAGE)

    food_name = _clean_text(item.get("food_name"), 120)
    if not food_name or not any(ch.isalnum() for ch in food_name):
        raise AnalysisError(502, INVALID_ESTIMATE_MESSAGE)

    confidence = _number(item.get("confidence"))
    raw_guess = _number(item.get("portion_guess_g"))
    raw_low = _number(item.get("portion_low_g"))
    raw_high = _number(item.get("portion_high_g"))
    if (
        confidence is None
        or raw_guess is None
        or raw_low is None
        or raw_high is None
        or not 0 <= confidence <= 1
        or not MIN_PORTION_G <= raw_low <= raw_guess <= raw_high <= MAX_PORTION_G
    ):
        raise AnalysisError(502, INVALID_ESTIMATE_MESSAGE)

    guess = int(max(MIN_PORTION_G, min(MAX_PORTION_G, round(raw_guess))))
    low = min(raw_low, max(MIN_PORTION_G, guess * 0.8))
    high = max(raw_high, min(MAX_PORTION_G, guess * 1.2))
    low_int = max(1, math.floor(low))
    high_int = min(int(MAX_PORTION_G), math.ceil(high))
    if low_int >= guess:
        low_int = max(1, guess - 1)
    if high_int <= guess:
        high_int = min(int(MAX_PORTION_G), guess + 1)
    if not low_int <= guess <= high_int:
        raise AnalysisError(502, INVALID_ESTIMATE_MESSAGE)

    nutrition = item.get("nutrition_per_100g")
    if not isinstance(nutrition, dict):
        raise AnalysisError(502, INVALID_NUTRITION_MESSAGE)
    calories = _number(nutrition.get("calories_kcal"))
    protein = _number(nutrition.get("protein_g"))
    carbs = _number(nutrition.get("carbs_g"))
    fat = _number(nutrition.get("fat_g"))
    if (
        calories is None
        or protein is None
        or carbs is None
        or fat is None
        or not 0 <= calories <= 900
        or any(not 0 <= macro <= 100 for macro in (protein, carbs, fat))
        or protein + carbs + fat > 105
    ):
        raise AnalysisError(502, INVALID_NUTRITION_MESSAGE)

    clarification = _clean_text(payload.get("clarification"), 200)
    return {
        "food_detected": True,
        "items": [
            {
                "food_name": food_name,
                "confidence": round(min(confidence, 0.95), 2),
                "portion_guess_g": guess,
                "portion_low_g": low_int,
                "portion_high_g": high_int,
                "nutrition_per_100g": {
                    "calories_kcal": round(calories, 1),
                    "protein_g": round(protein, 1),
                    "carbs_g": round(carbs, 1),
                    "fat_g": round(fat, 1),
                },
            }
        ],
        "clarification": clarification,
    }
