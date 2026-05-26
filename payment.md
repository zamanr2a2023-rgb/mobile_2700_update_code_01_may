# TruckFix — Frontend developer guide (Payments + Push)
 
Easy guide for mobile/web developers. **You call our REST API.** Our server talks to Stripe and Firebase. **Never put secret keys in the app.**
 
---
 
## 1. Basics
 
| Item | Value |
|------|--------|
| **Production API** | `https://kp-backend-1.onrender.com/api/v1` |
| **Local API** | `http://127.0.0.1:5000/api/v1` |
| **Login** | `POST /auth/login` → save `data.accessToken` |
| **Every protected call** | Header: `Authorization: Bearer <accessToken>` |
| **JSON** | Header: `Content-Type: application/json` |
 
**Response shape:**
 
```json
{ "status": "success", "message": "...", "data": { } }
```
 
**Errors:**
 
```json
{ "status": "fail", "message": "Human readable reason" }
```
 
---
 
## 2. Three user types — what each does with money
 
| User | Save card? | Pay when job done? | Stripe website redirect? |
|------|------------|--------------------|---------------------------|
| **Fleet** | Yes | Yes, **optional** (can approve without card) | No — card UI in app |
| **Company** | Yes | Yes, **required** | No — card UI in app |
| **Mechanic** | No | No (they get paid) | **Yes** — payout setup only |
 
---
 
## 3. The #1 mistake — two different “payment method IDs”
 
There are **two IDs**. They look different. **Do not swap them.**
 
| ID | Looks like | Use in |
|----|------------|--------|
| **Stripe PaymentMethod** | `pm_1TacpQIHodWKEvrfdanDwAJZ` | **Attach card** API only |
| **Our saved card id** | `6a1308428d3b1e57986af7dd` (24 characters) | **Approve job & pay** API |
 
**Remember:**
 
```text
Stripe SDK gives pm_...  →  POST attach  →  we return _id  →  PATCH approve uses _id
```
 
---
 
## 4. Payments — Fleet & Company (save a card)
 
### Screen: “Payment methods” / “Billing”
 
**Step 1 — Get Stripe publishable key**
 
```
GET /billing/stripe/config
```
 
Use `data.publishableKey` to init Stripe SDK (`flutter_stripe`, Stripe.js, etc.).
 
---
 
**Step 2 — Start add card**
 
```
POST /billing/stripe/setup-intent
Body: {}
```
 
You get:
 
- `clientSecret` → give to **Stripe SDK** (card form)
- `setupIntentId` → optional, send later on attach
 
**No browser redirect.** Card entry happens **inside your app** via Stripe SDK.
 
---
 
**Step 3 — User enters card (Stripe SDK)**
 
Example flow (Flutter idea):
 
1. Show Stripe card field
2. Confirm SetupIntent with `clientSecret`
3. SDK returns **`pm_...`**
 
You never send card number to our API — only Stripe handles that (PCI safe).
 
---
 
**Step 4 — Save card on our server**
 
```
POST /billing/stripe/payment-methods/attach
```
 
```json
{
  "paymentMethodId": "pm_1TacpQIHodWKEvrfdanDwAJZ",
  "isDefault": true,
  "setupIntentId": "seti_..."
}
```
 
**Save from response:**
 
- `data._id` → use for **job approve** (this is the Mongo id)
- `data.displayLabel` → show in UI (`visa **** 4242`)
 
---
 
**Step 5 — List cards**
 
```
GET /billing/payment-methods
```
 
Show list. Let user pick default card or delete:
 
- `PATCH /billing/payment-methods/:id/default`
- `DELETE /billing/payment-methods/:id`
 
---
 
## 5. Payments — Pay when job is finished
 
### When does payment happen?
 
```text
Mechanic marks job done
        ↓
Job status = AWAITING_APPROVAL
        ↓
Fleet or Company taps "Approve & Pay"
        ↓
Our server charges saved card (or manual for fleet only)
        ↓
Job = COMPLETED, invoice created
```
 
Payment is **not** at job post or quote accept.
 
---
 
### Fleet — approve job
 
```
PATCH /jobs/:jobId/complete/approve
```
 
**Pay with Stripe:**
 
```json
{
  "paymentMethodId": "6a1308428d3b1e57986af7dd",
  "finalAmount": 145
}
```
 
- `paymentMethodId` = **`data._id` from saved card** (NOT `pm_...`)
- `finalAmount` = optional
 
**Approve without Stripe** (fleet only — omit card):
 
```json
{ "finalAmount": 145 }
```
 
---
 
### Company — approve job (card required)
 
```
PATCH /company/jobs/:jobId/complete/approve
```
 
(or same path under `/jobs/...` with company token)
 
```json
{
  "paymentMethodId": "6a1308428d3b1e57986af7dd",
  "invoice": {
    "callOutCharge": 50,
    "labourHours": 2,
    "labourRatePerHour": 45,
    "parts": [{ "description": "Oil filter", "amount": 25 }]
  },
  "totalAmount": 165
}
```
 
- **`paymentMethodId` is required** for company
- If payment fails, job **stays** awaiting approval (not completed)
 
---
 
### What we charge
 
Backend calculates:
 
```text
charge ≈ job amount × 1.2   (includes 20% VAT)
```
 
Show user: subtotal + VAT = total before they tap Approve.
 
---
 
### Success response (both roles)
 
Check:
 
```json
data.invoice.payment.status === "SUCCEEDED"
data.invoice.status === "PAID"
data.job.status === "COMPLETED"
```
 
Save `data.invoice.payment.stripePaymentIntentId` (`pi_...`) if you need sync later.
 
---
 
## 6. 3D Secure / payment still processing
 
Sometimes approve returns **HTTP 402** — card needs bank verification or payment pending.
 
**What to do:**
 
1. Show message: “Complete verification with your bank”
2. If you have `clientSecret` from Stripe, run SDK confirm
3. Call sync:
 
```
POST /billing/stripe/payment-intents/:paymentIntentId/sync
```
 
No body. Use `pi_...` from approve response or invoice.
 
4. If `data.paymentStatus === "SUCCEEDED"` → show success
 
This route **does not charge again** — it only **refreshes status from Stripe**.
 
---
 
## 7. Mechanic — payout setup (only flow that opens Stripe website)
 
Mechanics do **not** save cards in the app. They connect a **bank account** for payouts.
 
**Check status:**
 
```
GET /billing/stripe/mechanic-payout-account
```
 
Look at `data.status`:
 
- `not_started` → show “Set up payouts”
- `needs_onboarding` → open onboarding link
- `ready` → done
 
**Start onboarding — returns Stripe URL:**
 
```
POST /billing/stripe/mechanic-payout-account/onboarding-link
```
 
```json
{
  "returnUrl": "truckfix://stripe/return",
  "refreshUrl": "truckfix://stripe/refresh"
}
```
 
**Open `data.url` in browser or WebView** → user is on Stripe’s site.
 
**After onboarding — open dashboard (optional):**
 
```
POST /billing/stripe/mechanic-payout-account/dashboard-link
Body: {}
```
 
Open `data.url`.
 
---
 
## 8. Push notifications
 
### How it works
 
```text
Something happens (chat, job update, etc.)
        ↓
Our server saves notification in DB
        ↓
Our server sends FCM push to registered devices
        ↓
User taps notification → open correct screen
```
 
### What frontend must do
 
**After login — register device FCM token:**
 
```
POST /notifications/device-tokens
```
 
```json
{
  "token": "<real FCM token from Firebase on device>",
  "platform": "android",
  "appVersion": "1.0.0"
}
```
 
`platform`: `"android"` | `"ios"` | `"web"`
 
**Use same Firebase project as backend** (`google-services.json` / `GoogleService-Info.plist`).
 
---
 
### List / read notifications
 
```
GET /notifications?page=1&limit=20
GET /notifications/:id
PATCH /notifications/:id/read
```
 
---
 
### Enable push for user
 
```
PATCH /users/me/preferences
```
 
```json
{
  "pushEnabled": true,
  "notifications": {
    "appAlerts": true,
    "systemAlerts": true
  }
}
```
 
If `pushEnabled: false`, server will not send FCM even if token exists.
 
---
 
### Notification tap — navigation
 
Push **data** includes fields like:
 
- `screen` — e.g. `JOB_CHAT`
- `jobId`, `messageId`, `notificationId`, `type`
 
Use these to navigate when user taps the notification.
 
Example: `type: CHAT_MESSAGE`, `screen: JOB_CHAT`, `jobId: ...` → open that job’s chat.
 
---
 
## 9. Suggested app screens
 
| Screen | APIs |
|--------|------|
| Login | `POST /auth/login` |
| Billing / Cards | config, setup-intent, attach, list, delete |
| Job detail (awaiting approval) | GET job, GET payment-methods, PATCH approve |
| Company approve + invoice lines | PATCH company approve with `invoice` object |
| Mechanic payouts | GET payout-account, POST onboarding-link, WebView |
| Notifications list | GET /notifications |
| Settings | PATCH /users/me/preferences |
 
---
 
## 10. Error codes — what to show users
 
| HTTP | Meaning | UI |
|------|---------|-----|
| 400 | Bad request / validation | Show `message` |
| 401 | Not logged in | Go to login |
| 402 | Payment failed / 3DS | Retry or sync PI |
| 403 | Wrong role | “Not allowed” |
| 404 | Job or card not found | Refresh data |
| 503 | Stripe not configured | Contact support |
 
---
 
## 11. Do NOT do this
 
- ❌ Put `STRIPE_SECRET_KEY` in the app  
- ❌ Send card number to our API  
- ❌ Use `pm_...` on job approve (use Mongo `_id`)  
- ❌ Use Mongo `_id` on attach (use `pm_...`)  
- ❌ Expect Stripe redirect for fleet/company card pay (SDK only)  
 
---
 
## 12. Quick test (Postman)
 
Import from repo:
 
- `postman/TruckFix.Stripe-Push.postman_collection.json`
- `postman/TruckFix.Stripe-Push.postman_environment.json`
 
Read: `postman/POSTMAN_STRIPE_PUSH.md`
 
Full API details: `docs/STRIPE_API_REFERENCE.md`
 
---
 
## 13. One-page cheat sheet
 
```text
LOGIN
  POST /auth/login → accessToken
 
ADD CARD (Fleet / Company)
  GET  /billing/stripe/config
  POST /billing/stripe/setup-intent
  → Stripe SDK (clientSecret) → pm_...
  POST /billing/stripe/payment-methods/attach  { paymentMethodId: "pm_..." }
  → save data._id
 
PAY JOB (Fleet — optional card)
  PATCH /jobs/:id/complete/approve  { paymentMethodId: "<mongo _id>" }
 
PAY JOB (Company — required card)
  PATCH /company/jobs/:id/complete/approve  { paymentMethodId: "<mongo _id>" }
 
REFRESH PAYMENT
  POST /billing/stripe/payment-intents/pi_xxx/sync
 
MECHANIC PAYOUT (opens Stripe URL)
  POST /billing/stripe/mechanic-payout-account/onboarding-link → open data.url
 
PUSH
  POST /notifications/device-tokens  { token, platform }
  GET  /notifications
  PATCH /users/me/preferences  { pushEnabled: true }
```
 
---
 
Questions? Check with backend team or test against Render: `https://kp-backend-1.onrender.com/api/v1`