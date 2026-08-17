# Card Key Derivation Safety

Safe patterns for deriving identity from card systems:

## 1. Hash Consistency
Hash same input = same output. Deterministic derivation.

## 2. No Secrets in Hashes
Card key derivation doesn't encode secrets. Only public provenance.

## 3. Collision Prevention
Use cryptographic hash (SHA-256+). Prevent identity collisions.

## 4. Verification Required
Always verify derived identity against authoritative source before trusting.

## 5. Audit Trail
Record: what was hashed, when, derived result, verification status.

**Enables safe identity verification in distributed agent systems.**
