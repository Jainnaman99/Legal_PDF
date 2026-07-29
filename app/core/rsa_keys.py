import base64
import json

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding as asym_padding


def _load_private_key():
    from app.core.config import settings
    if not settings.LOGIN_RSA_PRIVATE_KEY:
        raise RuntimeError(
            "LOGIN_RSA_PRIVATE_KEY is not set. "
            "Run scripts/generate_rsa_keys.py and add the key to .env"
        )
    pem = base64.b64decode(settings.LOGIN_RSA_PRIVATE_KEY)
    return serialization.load_pem_private_key(pem, password=None)


_private_key = _load_private_key()


def decrypt_login_payload(encrypted_b64: str) -> dict:
    ciphertext = base64.b64decode(encrypted_b64)
    # jsencrypt uses PKCS1v15 padding
    plaintext = _private_key.decrypt(ciphertext, asym_padding.PKCS1v15())
    return json.loads(plaintext.decode())
