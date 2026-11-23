# WoodCraft Customiser — Multi-App Suite

Complete 4-part system built with **PHP / Node.js + MySQL API**, **2 Flutter Apps**, and **React Admin Panel**.

## Project Structure

- **`php_api/`** — Production PHP + MySQL REST API deployed on cPanel with JWT RBAC, workshop privacy, AI Multi-Design Door Combiner, OTP Customer Auth, and Reports/CSV Export.
- **`backend/`** — Node.js + Express + MySQL REST API alternative.
- **`staff_app/`** — Flutter Staff App with role-based access for **Owner**, **Sales Team**, and **Production Team**.
- **`customer_app/`** — Flutter Customer App (Mobile Number OTP Login, Order Details & Live 8-Stage Production Tracker).
- **`adminpanel/`** — React + Vite Admin Panel (Staff/Role Access Management, Customers List, Orders List, Reports & CSV Export).

---

## 1. Database & API Setup (`php_api/` or `backend/`)

1. Import `php_api/schema.sql` into your MySQL database.
2. Configure database credentials in `php_api/config.php` (or `backend/.env` for Node.js).
3. Order numbers are automatically generated in `SUW-YYYY-XXXX` format.

### Staff Roles
| Role | Access |
|---|---|
| **Admin** | React Admin Panel (`adminpanel`) |
| **Owner** | Flutter Staff App (`staff_app`) & Admin Panel |
| **Sales Team** | Flutter Staff App (`staff_app`) |
| **Production Team** | Flutter Staff App (`staff_app`) — Technical Door Specs Only |

---

## 2. Build & Run React Admin Panel (`adminpanel/`)

```powershell
cd adminpanel
npm install
npm run build
```

---

## 3. Run Flutter Staff App (`staff_app/`)

```powershell
cd staff_app
flutter run
```

---

## 4. Run Flutter Customer App (`customer_app/`)

```powershell
cd customer_app
flutter run
```

Enter a registered customer mobile number (e.g. `76039 70435`) to log in and track orders.
