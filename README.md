# SecureAPI Dashboard

A complete, full-stack API Abuse & Rate Limiting Detection System.

## Features Overview

### 1. 📊 Live System Overview
- **Real-time KPI Metrics**: Tracks Total Requests, Block Rates, and Average Response Times over the last 24 hours.
- **Threat Tracking**: Displays the total count of active threats currently monitored by the system.
- **Traffic Volume Analysis**: A dynamic `Chart.js` graph that visualizes allowed vs blocked API traffic over time.

### 2. 🔍 Traffic Explorer
- **Raw Data View**: A paginated, easy-to-read table showing the raw API logs (Timestamp, IP Address, Endpoint, Status Code, and Final Decision).
- **CSV Export**: A one-click `Export as CSV` button that allows administrators to download the raw traffic logs for external analysis.

### 3. 🚨 Abuse Detection
- **Rule-based Scoring**: The system automatically scores IP addresses based on two primary abuse vectors:
  - **Credential Stuffing**: Unusually high rates of `4xx` errors.
  - **Endpoint Scraping**: Rapidly hitting multiple distinct endpoints across the application.
- **Risk Tiers**: Automatically categorizes threats into `Low`, `Medium`, `High`, and `Critical` tiers.

### 4. ⚙️ Settings & Configuration
- **Dynamic Rate Limits**: Administrators can dynamically update the `Max Requests Per Minute (RPM)` threshold. Changes are instantly saved to the MySQL database and applied to all incoming traffic.
- **System Maintenance**: A `Clear Database` button allows you to instantly purge all traffic logs and flagged entities, resetting the dashboard to a clean slate.

### 5. 🛠️ Dev Tools
- **Synthetic Traffic Generator**: The `Initialize & Seed Data` button in the top navigation bar utilizes the `Faker` library to instantly generate hundreds of realistic API requests, including injected scraping and burst attacks, to easily test the rate-limiting engine.
