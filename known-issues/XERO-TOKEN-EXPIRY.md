# Known Issue — Xero: Short-Lived OAuth Tokens

**Status:** Known limitation
**Affects:** xero-connector
**Symptom:** After 30 minutes of inactivity, Xero API calls start returning `401 Unauthorized` or `Token has expired`

---

## What Is Happening

Xero OAuth 2.0 access tokens expire after **30 minutes**. Once expired, any attempt to call the API (list invoices, fetch contacts, etc.) will fail with an auth error even though you connected successfully earlier.

The xero-connector uses the `xero-cli` to exchange a refresh token for a new access token. This process is normally automatic — but only if the refresh token itself is still valid.

---

## How to Fix It

Ask your assistant to reconnect:

> "My Xero connection expired. Please reconnect it."

Your assistant will run:
```bash
xero auth login
```

This opens a browser where you sign in to Xero and re-authorise the connection. The new tokens are saved locally and the previous session continues.

---

## If the Refresh Token Is Also Expired

Refresh tokens last up to **60 days** but expire early if:
- You revoked access in your Xero settings
- You haven't used the connector in 60 days
- Your Xero organisation's admin revoked third-party app access

If `xero auth refresh` fails, run the full reconnect:
```bash
xero auth login
```

---

## Preventing This

There is no persistent token fix available in the current connector version. Expect to reconnect once per session if you have not used Xero in the last 30 minutes. A future update may add automatic token refresh on every command call.

---

## Related

- Connector docs: `skills/xero-connector/SKILL.md`
- General auth errors: `docs/TROUBLESHOOTING.md`
