# Installer Test Key

`untrusted-public-key.asc` is a public key used only by the installer's negative
GPG verification test. It is not a TAFFISH release key and must never be trusted
for releases.

Fingerprint: `C6F188A4812C91A918DF649B69C8BD017B51F1F8`.

The test replaces the release public key in an isolated bundle with this valid
but unrelated key. The installer must reject its fingerprint before modifying
the destination. Tests need only this public key, never its private key or the
release private key.
