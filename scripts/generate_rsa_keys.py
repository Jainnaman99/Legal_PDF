"""
Run this ONCE to generate the RSA key pair:
    python scripts/generate_rsa_keys.py

Copy the output into:
  - .env  (the LOGIN_RSA_PRIVATE_KEY line)
  - src/services/crypto.js  (the PUBLIC_KEY_PEM constant)

Never re-run this unless you intentionally want to rotate keys —
rotating invalidates any in-flight logins.
"""
import base64

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

private_pem = key.private_bytes(
    serialization.Encoding.PEM,
    serialization.PrivateFormat.TraditionalOpenSSL,
    serialization.NoEncryption(),
).decode()

public_pem = key.public_key().public_bytes(
    serialization.Encoding.PEM,
    serialization.PublicFormat.SubjectPublicKeyInfo,
).decode()

private_b64 = base64.b64encode(private_pem.encode()).decode()

print("=" * 60)
print("ADD THIS LINE TO YOUR .env FILE:")
print("=" * 60)
print(f"LOGIN_RSA_PRIVATE_KEY={private_b64}")
print()
print("=" * 60)
print("PUT THIS IN src/services/crypto.js (replace the placeholder):")
print("=" * 60)
print(f"const PUBLIC_KEY_PEM = `{public_pem.strip()}`;")
