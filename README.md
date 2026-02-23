# Instagram Chat Analyzer (Full Stack)

This project is now a full-stack app:

- Flutter frontend (`lib/main.dart`) for upload + dashboard UI
- Node.js backend (`backend/`) with Express API
- SQLite SQL database (`backend/data/analytics.db`) for saved analyses

It preserves the existing Instagram chat metrics:

- message count per participant
- average response time per participant
- average sentiment per participant

## Architecture

- Frontend uploads an Instagram chat JSON export file.
- Backend analyzes the chat and stores result + raw conversation in SQLite.
- Frontend shows analysis history and detailed metrics for each upload.

## Prerequisites

- Flutter SDK 3.22+
- Node.js 18+

## Run Backend

```bash
cd backend
npm install
npm run dev
```

Backend runs on `http://localhost:4000` by default.

## Run Frontend

From the repository root:

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
```

You can also run on other Flutter targets.

## API Endpoints

- `GET /api/health`
- `GET /api/analyses`
- `GET /api/analyses/:id`
- `POST /api/analyses`
- `POST /api/non-followers`

Example upload body:

```json
{
	"fileName": "message_1.json",
	"conversation": {
		"participants": [{ "name": "User A" }, { "name": "User B" }],
		"messages": []
	}
}
```

Example followers/following comparison body:

```json
{
	"followers": { "relationships_followers": [] },
	"following": { "relationships_following": [] }
}
```
