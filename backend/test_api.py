import asyncio
import json
import os
import unittest
from unittest.mock import AsyncMock, patch

import httpx
from fastapi.testclient import TestClient

import main

JPEG = b"\xff\xd8\xff\xe0" + b"0" * 64
GIF = b"GIF89a" + b"0" * 64


def valid_payload() -> dict:
    return {
        "food_detected": True,
        "items": [
            {
                "food_name": "Grilled chicken breast",
                "confidence": 1.0,
                "portion_guess_g": 180,
                "portion_low_g": 140,
                "portion_high_g": 230,
                "nutrition_per_100g": {
                    "calories_kcal": 165,
                    "protein_g": 31,
                    "carbs_g": 0,
                    "fat_g": 3.6,
                },
            }
        ],
        "clarification": "",
    }


def image_request(
    client: TestClient,
    headers: dict | None = None,
    data: bytes = JPEG,
    mime: str = "image/jpeg",
):
    return client.post(
        "/api/analyze",
        files={"image": ("food.jpg", data, mime)},
        headers=headers or {},
    )


def deepseek_envelope(content: str | None = None) -> dict:
    return {
        "choices": [
            {
                "finish_reason": "stop",
                "message": {
                    "content": (
                        json.dumps(valid_payload()) if content is None else content
                    )
                },
            }
        ]
    }


class ScannerApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.env = patch.dict(
            os.environ,
            {
                "DEEPSEEK_API_KEY": "test-key-not-real",
                "SCANNER_ACCESS_TOKEN": "test-token-not-real",
            },
            clear=False,
        )
        self.env.start()
        self.addCleanup(self.env.stop)
        self.client = TestClient(main.app)

    def test_health(self) -> None:
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    def test_missing_token_is_rejected(self) -> None:
        with patch.object(main, "_run_deepseek", new=AsyncMock()) as model:
            response = image_request(self.client)
        self.assertEqual(response.status_code, 401)
        model.assert_not_called()

    def test_valid_scan_returns_clean_structured_result(self) -> None:
        with patch.object(
            main, "_run_deepseek", new=AsyncMock(return_value=valid_payload())
        ):
            response = image_request(
                self.client, headers={"x-scanner-token": "test-token-not-real"}
            )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers.get("cache-control"), "no-store")
        body = response.json()
        self.assertTrue(body["food_detected"])
        self.assertEqual(len(body["items"]), 1)
        item = body["items"][0]
        self.assertEqual(item["food_name"], "Grilled chicken breast")
        self.assertEqual(item["confidence"], 0.95)
        self.assertLess(item["portion_low_g"], item["portion_guess_g"])
        self.assertGreater(item["portion_high_g"], item["portion_guess_g"])

    def test_gif_is_accepted(self) -> None:
        with patch.object(
            main, "_run_deepseek", new=AsyncMock(return_value=valid_payload())
        ):
            response = image_request(
                self.client,
                headers={"x-scanner-token": "test-token-not-real"},
                data=GIF,
                mime="image/gif",
            )
        self.assertEqual(response.status_code, 200)

    def test_non_food_response_is_rejected(self) -> None:
        payload = valid_payload()
        payload["food_detected"] = False
        payload["items"] = []
        with patch.object(
            main, "_run_deepseek", new=AsyncMock(return_value=payload)
        ):
            response = image_request(
                self.client, headers={"x-scanner-token": "test-token-not-real"}
            )
        self.assertEqual(response.status_code, 422)
        self.assertIn("food", response.json()["detail"].lower())

    def test_invalid_model_json_is_a_clear_502(self) -> None:
        with patch.object(
            main,
            "_run_deepseek",
            new=AsyncMock(side_effect=main.ModelOutputError()),
        ):
            response = image_request(
                self.client, headers={"x-scanner-token": "test-token-not-real"}
            )
        self.assertEqual(response.status_code, 502)
        self.assertIn("unreadable", response.json()["detail"].lower())

    def test_invalid_image_is_rejected(self) -> None:
        with patch.object(main, "_run_deepseek", new=AsyncMock()):
            response = self.client.post(
                "/api/analyze",
                files={"image": ("food.jpg", b"not an image", "image/jpeg")},
                headers={"x-scanner-token": "test-token-not-real"},
            )
        self.assertEqual(response.status_code, 415)

    def test_missing_deepseek_key_is_503(self) -> None:
        with patch.dict(
            os.environ,
            {"SCANNER_ACCESS_TOKEN": "test-token-not-real"},
            clear=True,
        ):
            response = image_request(
                self.client, headers={"x-scanner-token": "test-token-not-real"}
            )
        self.assertEqual(response.status_code, 503)

    def test_provider_failure_does_not_echo_internals(self) -> None:
        with patch.object(
            main,
            "_run_deepseek",
            new=AsyncMock(side_effect=RuntimeError("secret upstream detail")),
        ):
            response = image_request(
                self.client, headers={"x-scanner-token": "test-token-not-real"}
            )
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("secret upstream detail", response.text)


class DeepSeekProviderTests(unittest.TestCase):
    def test_request_shape_and_json_parsing(self) -> None:
        captured: dict = {}

        def handler(request: httpx.Request) -> httpx.Response:
            captured["authorization"] = request.headers.get("authorization")
            captured["body"] = json.loads(request.content)
            return httpx.Response(200, json=deepseek_envelope())

        async def call() -> dict:
            transport = httpx.MockTransport(handler)
            async with httpx.AsyncClient(transport=transport) as client:
                return await main._run_deepseek(
                    "test-key-not-real",
                    JPEG,
                    "image/jpeg",
                    client=client,
                )

        payload = asyncio.run(call())
        self.assertEqual(payload["food_detected"], True)
        body = captured["body"]
        self.assertEqual(body["model"], "deepseek-flash")
        self.assertEqual(body["response_format"], {"type": "json_object"})
        self.assertGreater(body["max_tokens"], 0)
        self.assertEqual(body["messages"][0]["role"], "user")
        content = body["messages"][0]["content"]
        self.assertIn("json", content[0]["text"].lower())
        self.assertTrue(content[1]["image_url"]["url"].startswith("data:image/jpeg;base64,"))
        self.assertEqual(captured["authorization"], "Bearer test-key-not-real")

    def test_content_with_code_fences_is_still_parsed(self) -> None:
        content = "```json\n" + json.dumps(valid_payload()) + "\n```"
        parsed = main.parse_json_content(content)
        self.assertEqual(parsed["items"][0]["food_name"], "Grilled chicken breast")

    def test_blank_content_is_rejected(self) -> None:
        with self.assertRaises(main.ModelOutputError):
            main.parse_json_content("   ")

    def test_truncated_response_is_rejected(self) -> None:
        envelope = deepseek_envelope()
        envelope["choices"][0]["finish_reason"] = "length"
        with self.assertRaises(main.ModelOutputError):
            main._content_from_response(envelope)

    def test_provider_rate_limit_maps_to_429(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(429, json={"error": "busy"})

        async def call() -> None:
            transport = httpx.MockTransport(handler)
            async with httpx.AsyncClient(transport=transport) as client:
                await main._run_deepseek(
                    "test-key-not-real",
                    JPEG,
                    "image/jpeg",
                    client=client,
                )

        with self.assertRaises(main.ProviderError) as context:
            asyncio.run(call())
        self.assertEqual(context.exception.status_code, 429)

    def test_provider_timeout_maps_to_504(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ReadTimeout("timed out", request=request)

        async def call() -> None:
            transport = httpx.MockTransport(handler)
            async with httpx.AsyncClient(transport=transport) as client:
                await main._run_deepseek(
                    "test-key-not-real",
                    JPEG,
                    "image/jpeg",
                    client=client,
                )

        with self.assertRaises(main.ProviderError) as context:
            asyncio.run(call())
        self.assertEqual(context.exception.status_code, 504)


if __name__ == "__main__":
    unittest.main()
