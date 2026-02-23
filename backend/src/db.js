import { open } from 'sqlite';
import sqlite3 from 'sqlite3';

let db;

export async function initDatabase() {
  db = await open({
    filename: './data/analytics.db',
    driver: sqlite3.Database,
  });

  await db.exec(`
    CREATE TABLE IF NOT EXISTS analyses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      file_name TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      summary_json TEXT NOT NULL,
      conversation_json TEXT NOT NULL
    );
  `);

  return db;
}

export function getDatabase() {
  if (!db) {
    throw new Error('Database has not been initialized.');
  }

  return db;
}

export function parseSummary(summaryJson) {
  return JSON.parse(summaryJson);
}

export function parseConversation(conversationJson) {
  return JSON.parse(conversationJson);
}
