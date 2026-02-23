import cors from 'cors';
import express from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { analyzeConversation } from './analyzer.js';
import { getDatabase, initDatabase, parseConversation, parseSummary } from './db.js';

const app = express();
const port = Number(process.env.PORT || 4000);

app.use(cors());
app.use(express.json({ limit: '25mb' }));

app.get('/api/health', (_, res) => {
  res.json({ status: 'ok' });
});

function normalizeUsername(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim().toLowerCase();
  if (!normalized) {
    return null;
  }

  return normalized;
}

function extractUsernameFromHref(href) {
  if (typeof href !== 'string' || href.trim().length === 0) {
    return null;
  }

  try {
    const url = new URL(href);
    const pathParts = url.pathname.split('/').filter(Boolean);
    if (pathParts.length === 0) {
      return null;
    }

    if (pathParts[0] === '_u' && pathParts.length > 1) {
      return normalizeUsername(pathParts[1]);
    }

    return normalizeUsername(pathParts[0]);
  } catch {
    return null;
  }
}

function collectUsernamesFromNode(node, usernames) {
  if (node == null) {
    return;
  }

  if (Array.isArray(node)) {
    for (const item of node) {
      collectUsernamesFromNode(item, usernames);
    }
    return;
  }

  if (typeof node !== 'object') {
    return;
  }

  const typedNode = node;
  if (Array.isArray(typedNode.string_list_data)) {
    let foundUsernameInNode = false;

    for (const dataItem of typedNode.string_list_data) {
      const fromValue = normalizeUsername(dataItem?.value);
      if (fromValue) {
        usernames.add(fromValue);
        foundUsernameInNode = true;
        continue;
      }

      const fromHref = extractUsernameFromHref(dataItem?.href);
      if (fromHref) {
        usernames.add(fromHref);
        foundUsernameInNode = true;
      }
    }

    if (!foundUsernameInNode) {
      const fromTitle = normalizeUsername(typedNode.title);
      if (fromTitle) {
        usernames.add(fromTitle);
      }
    }
  }

  for (const value of Object.values(typedNode)) {
    collectUsernamesFromNode(value, usernames);
  }
}

function extractUsernames(payload) {
  const usernames = new Set();
  collectUsernamesFromNode(payload, usernames);
  return usernames;
}

function countRelationshipUnits(node) {
  if (node == null) {
    return 0;
  }

  if (Array.isArray(node)) {
    return node.reduce((sum, item) => sum + countRelationshipUnits(item), 0);
  }

  if (typeof node !== 'object') {
    return 0;
  }

  let total = 0;
  const typedNode = node;

  if (Array.isArray(typedNode.string_list_data) && typedNode.string_list_data.length > 0) {
    total += 1;
  }

  for (const value of Object.values(typedNode)) {
    total += countRelationshipUnits(value);
  }

  return total;
}

app.post('/api/non-followers', (req, res) => {
  try {
    const followersData = req.body?.followers;
    const followingData = req.body?.following;

    if (!followersData || !followingData) {
      return res.status(400).json({
        message: 'Invalid request. Expected followers and following JSON payloads.',
      });
    }

    const followerUsernames = extractUsernames(followersData);
    const followingUsernames = extractUsernames(followingData);
    const followerUnits = countRelationshipUnits(followersData);
    const followingUnits = countRelationshipUnits(followingData);

    const notFollowingBack = Array.from(followingUsernames)
      .filter((username) => !followerUsernames.has(username))
      .sort((a, b) => a.localeCompare(b));

    const youDontFollowBack = Array.from(followerUsernames)
      .filter((username) => !followingUsernames.has(username))
      .sort((a, b) => a.localeCompare(b));

    return res.json({
      totalFollowers: followerUnits,
      totalFollowing: followingUnits,
      uniqueFollowers: followerUsernames.size,
      uniqueFollowing: followingUsernames.size,
      notFollowingBackCount: notFollowingBack.length,
      notFollowingBack,
      youDontFollowBackCount: youDontFollowBack.length,
      youDontFollowBack,
    });
  } catch (error) {
    return res.status(400).json({
      message: error.message || 'Unable to compare followers and following JSON.',
    });
  }
});

app.post('/api/analyses', async (req, res) => {
  try {
    const conversation = req.body?.conversation;
    const fileName = typeof req.body?.fileName === 'string' && req.body.fileName.trim().length > 0
      ? req.body.fileName.trim()
      : 'messages.json';

    if (!conversation || typeof conversation !== 'object') {
      return res.status(400).json({
        message: 'Invalid request. Expected a conversation object.',
      });
    }

    const summary = analyzeConversation(conversation);
    const db = getDatabase();
    const insertResult = await db.run(
      `
        INSERT INTO analyses(file_name, summary_json, conversation_json)
        VALUES(?, ?, ?)
      `,
      fileName,
      JSON.stringify(summary),
      JSON.stringify(conversation),
    );

    const row = await db.get(
      `
        SELECT id, file_name, created_at, summary_json, conversation_json
        FROM analyses
        WHERE id = ?
      `,
      insertResult.lastID,
    );

    return res.status(201).json({
      id: row.id,
      fileName: row.file_name,
      createdAt: row.created_at,
      summary: parseSummary(row.summary_json),
      conversation: parseConversation(row.conversation_json),
    });
  } catch (error) {
    return res.status(400).json({
      message: error.message || 'Unable to analyze conversation.',
    });
  }
});

app.get('/api/analyses', async (_, res) => {
  const db = getDatabase();
  const rows = await db.all(
    `
      SELECT id, file_name, created_at, summary_json
      FROM analyses
      ORDER BY id DESC
      LIMIT 200
    `,
  );

  const analyses = rows.map((row) => ({
    id: row.id,
    fileName: row.file_name,
    createdAt: row.created_at,
    summary: parseSummary(row.summary_json),
  }));

  res.json({ analyses });
});

app.get('/api/analyses/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (Number.isNaN(id)) {
    return res.status(400).json({ message: 'Invalid analysis id.' });
  }

  const db = getDatabase();
  const row = await db.get(
    `
      SELECT id, file_name, created_at, summary_json, conversation_json
      FROM analyses
      WHERE id = ?
    `,
    id,
  );

  if (!row) {
    return res.status(404).json({ message: 'Analysis not found.' });
  }

  return res.json({
    id: row.id,
    fileName: row.file_name,
    createdAt: row.created_at,
    summary: parseSummary(row.summary_json),
    conversation: parseConversation(row.conversation_json),
  });
});

async function bootstrap() {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  const dataDirectory = path.resolve(__dirname, '../data');

  if (!fs.existsSync(dataDirectory)) {
    fs.mkdirSync(dataDirectory, { recursive: true });
  }

  await initDatabase();

  app.listen(port, () => {
    console.log(`API is running on http://localhost:${port}`);
  });
}

bootstrap();
