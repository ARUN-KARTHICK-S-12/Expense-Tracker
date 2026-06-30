# Wealth Tracker (Flutter + Google Sheets, no GCP)

Android expense and investment tracker that stores all data in **your own Google Sheet**. The app talks to the sheet through **Google Apps Script** deployed as a web app — no Google Cloud Platform project, service account, or API keys.

## Features

- **Expenses** — description, category, amount, date; monthly total on the list screen
- **Investments** — same fields, tracked separately
- **Categories** — predefined lists plus custom categories; custom entries appear in the same dropdown as predefined; rename from category management (updates existing rows in the sheet)
- **Analytics dashboard** — line charts for expense/investment trends; category breakdown bars; filter by **day**, **week**, **month**, or **year** with a reference date

## Project layout

```
expense-tracker/
├── google_apps_script/Code.gs   # Paste into your sheet's Apps Script editor
├── expense_tracker_app/       # Flutter Android app
└── README.md
```

## 1. Google Sheet setup (one-time)

1. Create a new [Google Sheet](https://sheets.google.com).
2. **Extensions → Apps Script**, delete any sample code, and paste the contents of `google_apps_script/Code.gs`.
3. **Deploy → New deployment → Web app**
   - Execute as: **Me**
   - Who has access: **Anyone** ← required; do **not** use "Anyone with Google account"
4. Copy the **Web app URL** (ends with `/exec`).
5. Initialize the sheet (pick **one**):
   - **Easiest:** In Apps Script, select **`runSetup`** in the function dropdown → **Run** → authorize if asked. Check your spreadsheet for new tabs.
   - **Browser:** Open `YOUR_URL?action=setup` (must be the **Web app** URL ending in `/exec`, from Deploy → Manage deployments).
   - **If `?action=` is lost after redirect:** use `YOUR_URL/setup` instead (path right after `/exec/`).

   Success looks like: `{"success":true,"message":"Sheets initialized."}`

   If you see `"Unknown action: "` with nothing after the colon, the request had no `action` — use **`runSetup`** in the editor or redeploy and try `/setup` on the URL.

Your data stays in this spreadsheet on your Google account.

## 2. Build the Flutter app

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install) with Android toolchain.

```powershell
cd "d:\\expense_tracker_app"
flutter pub get
flutter run
```

Release APK:

```powershell
flutter build apk --release
```

Output: `expense_tracker_app/build/app/outputs/flutter-apk/app-release.apk`

Install on your phone (USB debugging or copy the APK).

## 3. Connect the app

1. Open the app → **Settings** (or the first-run prompt).
2. Paste your **Web app URL**.
3. Tap **Save & Initialize Sheet** (safe to run again; it won't wipe existing data).

## Sheet structure

| Tab | Columns |
|-----|---------|
| Expenses | id, description, category, amount, date |
| Investments | id, description, category, amount, date |
| ExpenseCategories | name, isCustom |
| InvestmentCategories | name, isCustom |

Predefined categories are seeded on first `setup`. Custom categories are appended with `isCustom = true`.

## Security notes

- The web app runs as **you**; anyone with the URL can read/write if access is **Anyone**. For personal use on one device, that is usually acceptable; use **Anyone with Google account** or keep the URL private.
- No GCP billing or Cloud Console project is required.
- Currency display uses **₹** in the app; change `lib/utils/formatters.dart` if you prefer another symbol.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `FormatException` / HTML / sign-in page | Redeploy with **Who has access: Anyone**; paste the `/exec` URL, not the Sheet URL |
| `Unknown action: ` | Run **`runSetup`** in Apps Script editor, or use `?action=setup` on the `/exec` URL |
| Empty data | Run setup; confirm sheet tabs exist |
| HTTP error | Check phone network; URL must start with `https://script.google.com/macros/s/` |
| Flutter not found | Install Flutter and add it to PATH, then run `flutter doctor` |

## Tech stack

- Flutter 3.x, Provider, `http`, `fl_chart`, `shared_preferences`, `intl`
- Google Apps Script as REST API over Google Sheets
