# Privacy Policy

**Last updated:** June 2026

## Overview

This Privacy Policy describes how the **Coffee** mobile application ("we", "our", or "the app") collects, uses, stores, and protects your information. The app is a business productivity tool designed for managing coffee farmer collections, store data, and associated operations.

By using the app, you agree to the practices described in this policy.

---

## 1. Information We Collect

### 1.1 Information You Provide

| Data Type | Examples | Purpose |
|-----------|----------|---------|
| **Account credentials** | Username, password, name, email, phone number | User authentication and session management |
| **Farmer records** | Farmer name, ID number, phone, email, bank account details, farm acreage, number of trees, loan information | Farmer management and collection tracking |
| **Collection data** | Coffee weights (kg), collection dates, coffee type, payment status, gross/tare weights, number of bags, delivery details | Daily coffee collection recording and reporting |
| **Store data** | Store headers and line items | Store inventory and transaction management |
| **Business Central settings** | OData URL, company name, factory/division | Connection configuration for data synchronization |

### 1.2 Information Collected Automatically

- **Device permissions**: Bluetooth status (to connect to thermal printers and scales)
- **Network state**: Internet connectivity status (to sync data with the server)

### 1.3 No Sensitive Data Collected

We do **not** collect:
- Precise location data (beyond what is required for Bluetooth discovery on older Android versions)
- Biometric data
- Health or medical information
- Children's personal data
- Payment card information

---

## 2. How We Use Your Information

We use the collected information solely for:

- **App functionality**: Recording and managing coffee farmer collections
- **Data synchronization**: Syncing data with your organization's Microsoft Business Central server
- **Authentication**: Verifying user identity and managing access rights
- **Receipt printing**: Printing collection receipts via Bluetooth thermal printers
- **Reporting**: Generating collection reports and summaries

---

## 3. Data Storage and Security

### 3.1 Local Storage
All data is stored locally on your device using **SQLite** database encryption. Data remains on the device unless explicitly synced.

### 3.2 Data Transmission
When syncing, data is transmitted over **HTTPS** (TLS-encrypted) to your organization's Microsoft Business Central OData endpoint. The server URL is configured by your organization.

### 3.3 Data Retention
- **Local data**: Retained on device until the app is uninstalled or data is cleared in app settings
- **Server data**: Retained according to your organization's data retention policies in Microsoft Business Central

---

## 4. Data Sharing and Disclosure

We **do not** sell, rent, or share your personal data with third parties.

Data may be shared only in these circumstances:

| Scenario | Details |
|----------|---------|
| **Your organization** | Data is synced to your company's Microsoft Business Central server |
| **Legal requirement** | If required by law, regulation, or legal process |
| **Service providers** | Microsoft (Azure/Business Central infrastructure) — data stays within your organization's tenant |

---

## 5. Data Deletion

You can request deletion of your data in two ways:

1. **In-app**: Uninstall the app to remove all local data
2. **Server data**: Contact your organization's administrator to request deletion of data stored in Microsoft Business Central
3. **Contact us**: Email the address below for assistance

---

## 6. Permissions

The app requests the following permissions:

| Permission | Why It's Needed |
|------------|----------------|
| **Bluetooth** | To connect to Bluetooth thermal printers for printing collection receipts |
| **Bluetooth Admin** | To discover and pair with nearby Bluetooth printers and scales |
| **Location** (legacy Android) | Required on Android 10 and below to discover Bluetooth devices |
| **Internet** | To sync data with the Microsoft Business Central server |
| **Network State** | To check network availability before syncing |

---

## 7. Children's Privacy

This app is a business productivity tool intended for adults working in the coffee industry. It is **not** designed for or targeted at children under the age of 13. We do not knowingly collect data from children.

---

## 8. Your Rights

Depending on your jurisdiction, you may have the right to:

- **Access** the personal data we hold about you
- **Correct** inaccurate data
- **Delete** your data (see Section 5)
- **Object to** or **restrict** processing of your data
- **Data portability** — export your data

To exercise these rights, contact your organization's administrator or reach out to us using the contact details below.

---

## 9. Changes to This Policy

We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated "Last updated" date. We encourage you to review this policy periodically.

---

## 10. Contact Us

If you have questions, concerns, or requests regarding this Privacy Policy, please contact:

**Organization:** Trimline  
**Email:** *(insert your organization's email)*  
**Address:** *(insert your organization's address)*

---

## 11. Governing Law

This Privacy Policy is governed by the laws of the Republic of Kenya.
