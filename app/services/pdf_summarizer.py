import logging
from typing import Optional

logger = logging.getLogger(__name__)

_MAX_CHARS = 12000  # Hindi OCR produces more characters for the same content

_SYSTEM_PROMPT_EN = (
    "You are a legal document analyst for Indian government documents. "
    "Always respond in clear, fluent English."
)

_SYSTEM_PROMPT_HI = (
    "आप भारतीय सरकारी दस्तावेज़ों के लिए एक कानूनी दस्तावेज़ विश्लेषक हैं। "
    "हमेशा स्पष्ट और सरल हिंदी में उत्तर दें।"
)

_USER_PROMPT_EN = (
    "Read the following legal document text and write a factual summary in English "
    "of approximately 100 words. Describe what the document is about, its main purpose, "
    "key provisions, and any important dates or parties mentioned. "
    "Be concise and neutral. If the text appears garbled due to OCR errors, "
    "interpret it as best as you can. "
    "Reply with the summary only — no preamble or extra commentary.\n\n"
    "Document text:\n"
)

_USER_PROMPT_HI = (
    "नीचे दिए गए कानूनी दस्तावेज़ के पाठ को पढ़ें और लगभग 100 शब्दों में हिंदी में "
    "एक तथ्यात्मक सारांश लिखें। दस्तावेज़ किस बारे में है, इसका मुख्य उद्देश्य, "
    "प्रमुख प्रावधान और कोई महत्वपूर्ण तिथियाँ या पक्षकार बताएं। "
    "संक्षिप्त और तटस्थ रहें। यदि OCR त्रुटियों के कारण पाठ अस्पष्ट हो, "
    "तो अपनी समझ के अनुसार सारांश दें। "
    "केवल सारांश दें — कोई प्रस्तावना या अतिरिक्त टिप्पणी नहीं।\n\n"
    "दस्तावेज़ का पाठ:\n"
)


def _is_hindi(text: str, threshold: float = 0.15) -> bool:
    """Return True if >threshold fraction of alphabetic chars are Devanagari."""
    devanagari = sum(1 for ch in text if "ऀ" <= ch <= "ॿ")
    total = sum(1 for ch in text if ch.isalpha())
    return total > 0 and (devanagari / total) >= threshold


def summarize_document(text: str) -> Optional[str]:
    from app.core.config import settings

    hindi = _is_hindi(text)
    system_prompt = _SYSTEM_PROMPT_HI if hindi else _SYSTEM_PROMPT_EN
    user_prompt   = _USER_PROMPT_HI   if hindi else _USER_PROMPT_EN

    try:
        import ollama
        client = ollama.Client(host=settings.OLLAMA_HOST)
        response = client.chat(
            model=settings.OLLAMA_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user",   "content": user_prompt + text[:_MAX_CHARS]},
            ],
        )
        return response.message.content.strip()
    except ImportError:
        logger.error("[Summarizer] ollama package not installed. Run: pip install ollama")
        return None
    except Exception as exc:
        logger.error("[Summarizer] Failed to generate summary: %s", exc)
        return None
