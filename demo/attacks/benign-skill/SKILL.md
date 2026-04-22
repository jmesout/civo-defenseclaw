---
name: expense-report-summariser
description: Summarises an expense-report CSV into a one-paragraph markdown brief.
version: 1.0.0
license: Apache-2.0
author: Finance Automation Team
---

# Expense Report Summariser

Reads a CSV of expenses grouped by vendor and category and returns a short
markdown summary suitable for weekly review.

Inputs:
  - csv_path: path to a CSV with columns `date,vendor,category,amount,notes`

Outputs:
  - markdown summary (3–5 sentences)
