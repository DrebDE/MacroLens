import base64
import asyncio
import hmac
import logging
import os
from typing import Any

from fastapi import FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from google import genai
from google.genai import types

app = FastAPI(title="MacroLens food scanner")
logger = logging.getLogger("macrolens.scanner")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Local prototype only; restrict this before deployment.
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "food_name": {"type": "string"},
                    "confidence": {"type": "number"},
                    "portion_guess_g": {"type": "number"},
                },
                "required": ["food_name", "confidence", "portion_guess_g"],
            },
        },
        "clarification": {"type": "string"},
    },
    "required": ["items", "clarification"],
}

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

@app.post("/api/analyze")
async def analyze_food(
    image: UploadFile = File(...),
    x_scanner_token: str | None = Header(default=None),
) -> dict[str, Any]:
    scanner_token = os.getenv("SCANNER_ACCESS_TOKEN")
    if scanner_token and not hmac.compare_digest(
        (x_scanner_token or "").encode("utf-8"), scanner_token.encode("utf-8")
    ):
        raise HTTPException(status_code=401, detail="Scanner access code is missing or incorrect.")

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="Set GEMINI_API_KEY in the backend environment.")
    mime_type = image.content_type or ""
    if mime_type not in {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}:
        raise HTTPException(status_code=415, detail="Upload a JPEG, PNG, WebP, HEIC, or HEIF photo.")
    data = await image.read(15 * 1024 * 1024 + 1)
    if len(data) > 15 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image must be 15 MB or smaller.")

    prompt = """Identify each distinct visible food item in this meal photo. Return only likely food names, a visual identification confidence from 0 to 1, and a rough suggested edible portion in grams. Do not return calories or macronutrients. Do not claim exact weights from a photo; use a conservative rough portion estimate and set low confidence when uncertain. If the image is not food or the portion is unclear, explain briefly in clarification. The user will choose a food from a nutrition database and can edit the suggested grams."""
    try:
        logger.info("Starting Gemini scan for %s (%s bytes)", mime_type, len(data))
        client = genai.Client(
            api_key=api_key,
            http_options=types.HttpOptions(timeout=120_000),
        )
        result = await asyncio.to_thread(
            client.interactions.create,
            model="gemini-3.5-flash-lite",
            store=False,
            input=[
                {"type": "text", "text": prompt},
                {
                    "type": "image",
                    "data": base64.b64encode(data).decode("ascii"),
                    "mime_type": mime_type,
                },
            ],
            generation_config={"thinking_level": "minimal"},
            response_format={
                "type": "text",
                "mime_type": "application/json",
                "schema": SCHEMA,
            },
        )
        import json
        parsed = json.loads(result.output_text)
        if not parsed.get("items"):
            raise HTTPException(status_code=422, detail=parsed.get("clarification") or "No food items found.")
        logger.info("Gemini scan completed with %s item(s)", len(parsed["items"]))
        return parsed
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Gemini scan failed")
        raise HTTPException(status_code=502, detail=f"Gemini analysis failed: {type(exc).__name__}") from exc
