# Coffee App User Manual

## Table of Contents

1. Purpose
2. Main Features
3. Before You Start
4. First-Time Setup
5. Permissions
6. Logging In
7. Navigation
8. Dashboard
9. Daily Collections
10. Farmers
11. Farmer Collections
12. Stores
13. Items
14. Bluetooth Settings
15. Business Central Settings
16. Collection Settings
17. User Management
18. Logout
19. Offline and Sync Behavior
20. Troubleshooting
21. Recommended Daily Workflow

## 1. Purpose

Coffee App is a field operations app for:

- logging daily coffee collections
- viewing farmer delivery totals
- managing store issue headers and lines
- maintaining local users and farmers
- connecting a Bluetooth printer and Bluetooth scale
- syncing selected data with Microsoft Dynamics 365 Business Central through OData

The app is designed to work offline first. Data is saved locally on the device and synced when Business Central is configured and reachable.

## 2. Main Features

- User login with optional "Remember me for today"
- First-time password setup for synced users with no local password yet
- Dashboard with today summary and recent collections
- Add and view daily collections
- Farmer list and per-day farmer collection totals
- Store headers and store lines
- Item list
- Bluetooth printer and scale attachment
- Business Central connection settings
- Collection tare weight settings
- Admin-only user management

## 3. Before You Start

Make sure the following are available:

- the app is installed on the device
- Bluetooth is turned on
- the printer and scale are already paired in the phone's Bluetooth settings
- Business Central OData URL, company, username, password, and factory are known
- the app has Bluetooth permission and, on some Android versions, Location permission

## 4. First-Time Setup

When the app opens for the first time and no users are loaded locally, it opens **Business Central Settings** automatically.

Enter:

- **OData Base URL**
- **Company**
- **Username**
- **Password**
- **Factory**

Tap **Load** beside the factory field if you want the app to fetch the factory list from Business Central. Then tap **Save**.

After saving, the app attempts to load users and farmers from Business Central. If no users are loaded, check the Business Central details and try again.

## 5. Permissions

On startup, the app may show **Permissions required**.

Tap **Grant permissions** to allow:

- Bluetooth access
- Location access where required by Android for Bluetooth discovery

If permission was denied permanently, tap **Open app settings** and enable the required permissions manually.

## 6. Logging In

Open the login screen and enter:

- **Username**
- **Password**

Optional:

- enable **Remember me for today** to skip login until logout or the next day

### First login without a password

If your username exists locally but has no password yet, the app opens **Set password**. Enter and confirm a password, then save it. The password is stored locally and later pushed to Business Central when sync is available.

## 7. Navigation

Open the side drawer to move between screens:

- Dashboard
- Farmers
- Users
- Collections
- Stores
- Items
- Farmer Collections
- Bluetooth Settings
- Business Central
- Collection Settings
- Logout

The **Users** screen is visible only to users whose rights are set to **Admin**.

## 8. Dashboard

The dashboard shows:

- today's total kilograms
- number of farmers served today
- total farmers in local storage
- highest single collection for today
- recent collections

Available actions:

- **New**: add a collection
- **List**: open the full collections list
- **Print**: select and connect a printer
- top-right printer icon: select a paired printer
- receipt icon on a recent collection: print that collection's receipt
- refresh icon: reload dashboard data

## 9. Daily Collections

### Add a collection

Open **Dashboard > New** or **Collections > +**.

Steps:

1. Enter or search **Farmer Number**.
2. If needed, tap **Connect Scale** to read weight from the attached Bluetooth scale.
3. Enter **Kg Collected** manually or let the live scale update the field.
4. Review the farmer's **Previous deliveries** shown below.
5. Tap **Save Collection**.

What happens after saving:

- the collection is saved locally immediately
- the app tries to sync it to Business Central
- if Business Central is unavailable, the collection remains pending locally

### View collections

Open **Collections** to see all locally stored collections.

Use the filter box to search by:

- farmer number
- farmer name
- coffee type
- collection number

## 10. Farmers

Open **Farmers** to view the local farmer list and total collected kilograms per farmer.

### Add a farmer

Tap the **Add farmer** button and enter:

- Farmer No
- Name
- Phone
- Email
- ID No
- Factory

Tap **Save Farmer**.

### Update a farmer

Tap a farmer entry to edit:

- Phone
- Email
- ID No

Tap **Save Changes**.

### Refresh farmers from Business Central

Use the refresh action on the Farmers screen to reload farmers from Business Central.

## 11. Farmer Collections

Open **Farmer Collections** to see each farmer's total kilograms and transaction count for a selected day.

Available actions:

- calendar icon: choose a date
- search icon: filter by farmer number or name
- clear filter icon: reset filters

This screen is useful for end-of-day review by farmer.

## 12. Stores

The store workflow has two levels:

- **Store Header**: the main transaction
- **Store Line**: individual items under the header

### Add a store header

Open **Stores > +**.

Steps:

1. Search or enter the **Farmer Number**.
2. Enter **Amount Paid** if applicable.
3. Enter **Comments** if needed.
4. Tap **Add/Edit Lines** to add one or more store lines.
5. Return to the header screen and tap **Save Store Header**.

The app fills some values automatically:

- entry number
- collector name
- collector username
- factory from Business Central settings

When saved:

- the header is stored locally
- total and balance are computed from the lines
- if an attached printer is connected, the app prints a stores receipt automatically

### Add a store line

Inside a store header, tap **Add store line**.

Enter:

- Item
- Variant
- Quantity
- Amount
- Status
- Stock
- Crop
- Comments

Tap **Save Store Line**.

The line total is calculated from quantity multiplied by amount.

### View and edit store headers

Open **Stores** to see saved headers.

Tap a header to:

- review entry details
- edit farmer, factory, total, or comments
- open its lines

## 13. Items

Open **Items** to view the available item master list used when creating store lines.

Each item shows:

- item number
- description
- base unit of measure
- inventory
- unit price

Use refresh if the list does not look current.

## 14. Bluetooth Settings

Open **Bluetooth Settings** to manage both printer and scale devices.

### Printer setup

1. Pair the printer in Android Bluetooth settings first.
2. Open **Bluetooth Settings**.
3. Tap **Refresh** if needed.
4. Tap **Select Printer**.
5. Choose the paired device.
6. Tap **Attach**.

If attached successfully, the printer appears under **Attached Printer**.

Use **Detach** to remove it.

### Scale setup

1. Pair the scale in Android Bluetooth settings first.
2. Open **Bluetooth Settings**.
3. Tap **Select Scale**.
4. Choose the paired device.
5. Tap **Attach**.

To read live weight:

1. In **Scale Live Connection**, tap **Connect**.
2. Wait for the latest weight to appear.
3. Use the weight while adding a collection.

Use **Disconnect** to close the live scale session, or **Detach** to remove the stored scale attachment.

### If no devices appear

Check the following:

- Bluetooth is on
- permissions are granted
- the device is paired in system Bluetooth settings
- the printer supports classic Bluetooth printing

## 15. Business Central Settings

Open **Business Central** from the drawer to update connection details at any time.

Fields:

- OData Base URL
- Company
- Username
- Password
- Factory

Use **Load** to fetch available factories from Business Central. Tap **Save** to store the settings.

These settings affect:

- user sync
- farmer sync
- collection sync and filtering by factory

## 16. Collection Settings

Open **Collection Settings** to manage:

- **Tare Weight Per Bag (kg)**

Enter the tare weight and tap **Save Settings**.

## 17. User Management

Only admins can open **Users**.

### Add a user

Tap **Add User** and enter:

- Name
- Username
- Rights
- Password
- Email
- Phone

Tap **Create**.

The app creates the user in Business Central and stores it locally.

### Edit a user

Open the user menu and tap **Edit**.

You can update:

- Name
- Rights
- Password
- Email
- Phone

The username cannot be changed after creation.

### Delete a user

Open the user menu and tap **Delete**.

Important:

- deletion removes the user from the local device
- this action is not sent to Business Central

## 18. Logout

Use **Logout** from the drawer to end the current session.

If **Remember me for today** was enabled, logout clears that remembered session.

## 19. Offline and Sync Behavior

- collections are saved locally first
- the app attempts to sync new collections to Business Central
- if sync fails, collections remain local and can sync later
- synced users with empty passwords can set a password locally first
- pending password updates are retried later during sync-related operations
- farmers and users can be refreshed from Business Central

## 20. Troubleshooting

### I cannot log in

Check:

- the username exists locally
- the password is correct
- Business Central setup was completed at least once so users were loaded

If the user has no password yet, use the password setup screen when prompted.

### No users were loaded after setup

Check:

- OData Base URL
- company name
- Business Central username and password
- network connectivity
- selected factory

Then save Business Central settings again.

### Printer does not connect

Check:

- the printer is powered on
- Bluetooth is on
- the printer is paired in Android settings
- permissions are granted
- the printer supports classic Bluetooth printer mode

Then reopen **Bluetooth Settings**, refresh, and attach the printer again.

### Scale does not return weight

Check:

- the scale is powered on
- the scale is paired in Android settings
- the correct scale was attached
- Bluetooth permission is granted

Then reconnect from **Scale Live Connection**.

### A collection was saved but not synced

This usually means Business Central was unavailable at save time. The record is still local. Reconnect to Business Central and trigger sync-related activity again.

## 21. Recommended Daily Workflow

1. Confirm Business Central settings are correct.
2. Confirm Bluetooth printer and scale are attached.
3. Log in.
4. Use the dashboard to add daily collections.
5. Print receipts where needed.
6. Review totals in Farmer Collections.
7. Create store headers and lines if store issues are being recorded.
8. Logout at the end of the day.
