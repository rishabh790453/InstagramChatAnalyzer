# Backend

Express + SQLite backend for Instagram Chat Analyzer.

## Start

```bash
npm install
npm run dev
```

## Environment

Create a `.env` file from `.env.example` if needed.

- `PORT`: API port (default `4000`)

## SQL Storage

SQLite database file is created automatically at:

- `backend/data/analytics.db`

Table: `analyses`

- `id` (primary key)
- `file_name`
- `created_at`
- `summary_json`
- `conversation_json`

## Additional API

- `POST /api/non-followers`
	- Accepts two JSON payloads (`followers` and `following`) from Instagram export format.
	- Returns usernames you follow who do not follow you back.