import { join } from 'path';

/**
 * Local-disk store for player photos/ID documents (M1: no cloud storage
 * integration yet). Rooted at the backend package dir (not `dist/`) so
 * uploaded files survive a `nest build` and aren't wiped by `flutter clean`
 * or similar. Swap for S3/GCS-backed storage before this goes to production.
 */
export const UPLOADS_DIR = join(__dirname, '..', '..', '..', 'uploads');

export const MAX_UPLOAD_SIZE_BYTES = 10 * 1024 * 1024; // 10MB

export const ALLOWED_UPLOAD_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
