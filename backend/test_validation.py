import copy
import unittest

from validation import (
    AnalysisError,
    MAX_IMAGE_BYTES,
    validate_analysis,
    validate_image,
)


def valid_payload() -> dict:
    return {
        "food_detected": True,
        "items": [
            {
                "food_name": "Grilled chicken breast",
                "confidence": 0.82,
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


class AnalysisValidationTests(unittest.TestCase):
    def test_valid_response_is_cleaned(self) -> None:
        result = validate_analysis(valid_payload())
        self.assertTrue(result["food_detected"])
        self.assertEqual(len(result["items"]), 1)
        item = result["items"][0]
        self.assertEqual(item["food_name"], "Grilled chicken breast")
        self.assertEqual(item["confidence"], 0.82)
        self.assertEqual(item["portion_guess_g"], 180)
        self.assertEqual(item["portion_low_g"], 140)
        self.assertEqual(item["portion_high_g"], 230)
        self.assertEqual(
            item["nutrition_per_100g"],
            {
                "calories_kcal": 165.0,
                "protein_g": 31.0,
                "carbs_g": 0.0,
                "fat_g": 3.6,
            },
        )

    def test_non_food_is_rejected(self) -> None:
        payload = valid_payload()
        payload["food_detected"] = False
        payload["items"] = []
        with self.assertRaises(AnalysisError) as context:
            validate_analysis(payload)
        self.assertEqual(context.exception.status_code, 422)

    def test_true_without_items_is_rejected(self) -> None:
        payload = valid_payload()
        payload["items"] = []
        with self.assertRaises(AnalysisError) as context:
            validate_analysis(payload)
        self.assertEqual(context.exception.status_code, 422)

    def test_confidence_is_capped_below_one(self) -> None:
        payload = valid_payload()
        payload["items"][0]["confidence"] = 1.0
        result = validate_analysis(payload)
        self.assertEqual(result["items"][0]["confidence"], 0.95)

    def test_confidence_above_one_is_invalid(self) -> None:
        payload = valid_payload()
        payload["items"][0]["confidence"] = 1.2
        with self.assertRaises(AnalysisError) as context:
            validate_analysis(payload)
        self.assertEqual(context.exception.status_code, 502)

    def test_tight_portion_bounds_are_widened(self) -> None:
        payload = valid_payload()
        item = payload["items"][0]
        item["portion_guess_g"] = 100
        item["portion_low_g"] = 100
        item["portion_high_g"] = 100
        result = validate_analysis(payload)
        item = result["items"][0]
        self.assertLess(item["portion_low_g"], item["portion_guess_g"])
        self.assertGreater(item["portion_high_g"], item["portion_guess_g"])
        self.assertLessEqual(item["portion_low_g"], 80)
        self.assertGreaterEqual(item["portion_high_g"], 120)

    def test_low_above_guess_is_invalid(self) -> None:
        payload = valid_payload()
        payload["items"][0]["portion_low_g"] = 200
        with self.assertRaises(AnalysisError) as context:
            validate_analysis(payload)
        self.assertEqual(context.exception.status_code, 502)

    def test_portion_above_limit_is_invalid(self) -> None:
        payload = valid_payload()
        payload["items"][0]["portion_high_g"] = 5001
        with self.assertRaises(AnalysisError):
            validate_analysis(payload)

    def test_impossible_nutrition_is_rejected(self) -> None:
        payload = valid_payload()
        payload["items"][0]["nutrition_per_100g"]["protein_g"] = 120
        with self.assertRaises(AnalysisError) as context:
            validate_analysis(payload)
        self.assertEqual(context.exception.status_code, 502)

    def test_macros_that_exceed_mass_are_rejected(self) -> None:
        payload = valid_payload()
        payload["items"][0]["nutrition_per_100g"].update(
            {"protein_g": 40, "carbs_g": 40, "fat_g": 40}
        )
        with self.assertRaises(AnalysisError):
            validate_analysis(payload)

    def test_boolean_is_not_a_number(self) -> None:
        payload = valid_payload()
        payload["items"][0]["confidence"] = True
        with self.assertRaises(AnalysisError):
            validate_analysis(payload)

    def test_food_name_control_characters_are_cleaned(self) -> None:
        payload = valid_payload()
        payload["items"][0]["food_name"] = "  Grilled\nchicken\u0000 breast  "
        result = validate_analysis(payload)
        self.assertEqual(result["items"][0]["food_name"], "Grilled chicken breast")

    def test_food_name_is_bounded(self) -> None:
        payload = valid_payload()
        payload["items"][0]["food_name"] = "Chicken " * 40
        result = validate_analysis(payload)
        self.assertEqual(len(result["items"][0]["food_name"]), 120)

    def test_punctuation_only_name_is_rejected(self) -> None:
        payload = valid_payload()
        payload["items"][0]["food_name"] = "!!! ***"
        with self.assertRaises(AnalysisError):
            validate_analysis(payload)

    def test_only_first_item_is_returned(self) -> None:
        payload = valid_payload()
        second = copy.deepcopy(payload["items"][0])
        second["food_name"] = "Side salad"
        payload["items"].append(second)
        result = validate_analysis(payload)
        self.assertEqual(len(result["items"]), 1)
        self.assertEqual(result["items"][0]["food_name"], "Grilled chicken breast")

    def test_clarification_is_bounded(self) -> None:
        payload = valid_payload()
        payload["clarification"] = "x" * 500
        result = validate_analysis(payload)
        self.assertEqual(len(result["clarification"]), 200)


class ImageValidationTests(unittest.TestCase):
    def test_jpeg_signature(self) -> None:
        self.assertEqual(validate_image(b"\xff\xd8\xff\xe0" + b"0" * 20), "image/jpeg")

    def test_png_signature(self) -> None:
        self.assertEqual(validate_image(b"\x89PNG\r\n\x1a\n" + b"0" * 20), "image/png")

    def test_webp_signature(self) -> None:
        data = b"RIFF" + b"\x00\x00\x00\x00" + b"WEBP" + b"0" * 20
        self.assertEqual(validate_image(data), "image/webp")

    def test_gif_signature(self) -> None:
        self.assertEqual(validate_image(b"GIF89a" + b"0" * 20), "image/gif")
        self.assertEqual(validate_image(b"GIF87a" + b"0" * 20), "image/gif")

    def test_heic_is_rejected(self) -> None:
        data = b"\x00\x00\x00\x18ftypheic" + b"0" * 20
        with self.assertRaises(AnalysisError) as context:
            validate_image(data)
        self.assertEqual(context.exception.status_code, 415)

    def test_detected_image_type_is_returned(self) -> None:
        # The file signature, not the upload filename or declared metadata,
        # determines which supported image type is used.
        self.assertEqual(
            validate_image(b"\x89PNG\r\n\x1a\n" + b"0" * 20), "image/png"
        )

    def test_unknown_bytes_are_rejected(self) -> None:
        with self.assertRaises(AnalysisError) as context:
            validate_image(b"not an image")
        self.assertEqual(context.exception.status_code, 415)

    def test_empty_image_is_rejected(self) -> None:
        with self.assertRaises(AnalysisError) as context:
            validate_image(b"")
        self.assertEqual(context.exception.status_code, 400)

    def test_size_limit_constant_is_15_mb(self) -> None:
        self.assertEqual(MAX_IMAGE_BYTES, 15 * 1024 * 1024)


if __name__ == "__main__":
    unittest.main()
