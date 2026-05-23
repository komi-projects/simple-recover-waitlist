/**
 * SimpleRecover Waitlist Backend
 * Express.js API for email capture and count
 * Stores data in JSON file (no DB required)
 */

const express = require('express');
const fs = require('fs').promises;
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const DATA_FILE = path.join(__dirname, 'waitlist.json');

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname)));

// ───────────────────────────────────────────────
// Helpers
// ───────────────────────────────────────────────

/**
 * Read waitlist data from JSON file
 */
async function readData() {
  try {
    const raw = await fs.readFile(DATA_FILE, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === 'ENOENT') {
      return { entries: [], createdAt: new Date().toISOString() };
    }
    throw err;
  }
}

/**
 * Write waitlist data to JSON file
 */
async function writeData(data) {
  await fs.writeFile(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
}

/**
 * Validate email format
 */
function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/**
 * Normalize email (lowercase, trim)
 */
function normalizeEmail(email) {
  return email.toLowerCase().trim();
}

/**
 * Send welcome email (console.log for now — swap for SendGrid/Postmark/Resend)
 */
function sendWelcomeEmail(email) {
  const subject = 'Welcome to the SimpleRecover waitlist 👋';
  const body = `
Hey there,

You're on the SimpleRecover waitlist — welcome aboard.

Here's what happens next:

  • We build like crazy (follow along: github.com/zatarhq)
  • You get first access when we launch
  • Early adopters get 50% off for life

Questions? Just reply to this email.

— The SimpleRecover team
  `;

  console.log('\n📧 === WELCOME EMAIL ===');
  console.log(`To: ${email}`);
  console.log(`Subject: ${subject}`);
  console.log(`Body:\n${body}`);
  console.log('========================\n');

  // TODO: Integrate with email provider
  // Example with Resend:
  // const Resend = require('resend').Resend;
  // const resend = new Resend(process.env.RESEND_API_KEY);
  // await resend.emails.send({ from: 'hello@simplerecover.io', to: email, subject, text: body });
}

// ───────────────────────────────────────────────
// Routes
// ───────────────────────────────────────────────

/**
 * POST /api/waitlist
 * Join the waitlist
 */
app.post('/api/waitlist', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !isValidEmail(email)) {
      return res.status(400).json({ error: 'Valid email required.' });
    }

    const normalized = normalizeEmail(email);
    const data = await readData();

    // Check for duplicates
    const exists = data.entries.some(e => e.email === normalized);
    if (exists) {
      return res.status(409).json({ error: 'Email already on waitlist.' });
    }

    // Add entry
    const entry = {
      email: normalized,
      joinedAt: new Date().toISOString(),
      source: req.headers.referer || req.headers.origin || 'direct',
      userAgent: req.headers['user-agent'] || null
    };

    data.entries.push(entry);
    await writeData(data);

    // Send welcome email
    sendWelcomeEmail(normalized);

    return res.status(201).json({
      success: true,
      message: "You're on the waitlist!",
      position: data.entries.length
    });

  } catch (err) {
    console.error('POST /api/waitlist error:', err);
    return res.status(500).json({ error: 'Server error. Please try again.' });
  }
});

/**
 * GET /api/waitlist/count
 * Get total waitlist count (for social proof)
 */
app.get('/api/waitlist/count', async (req, res) => {
  try {
    const data = await readData();
    return res.json({ count: data.entries.length });
  } catch (err) {
    console.error('GET /api/waitlist/count error:', err);
    return res.status(500).json({ error: 'Server error.' });
  }
});

/**
 * GET /api/waitlist
 * Get all entries (admin/debug — protect in production)
 */
app.get('/api/waitlist', async (req, res) => {
  try {
    const data = await readData();
    // In production, add auth middleware here
    return res.json({
      count: data.entries.length,
      entries: data.entries.map(e => ({ email: e.email, joinedAt: e.joinedAt }))
    });
  } catch (err) {
    console.error('GET /api/waitlist error:', err);
    return res.status(500).json({ error: 'Server error.' });
  }
});

/**
 * Health check
 */
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ───────────────────────────────────────────────
// Start Server
// ───────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`🚀 SimpleRecover waitlist server running on port ${PORT}`);
  console.log(`📁 Data file: ${DATA_FILE}`);
  console.log(`🌐 http://localhost:${PORT}`);
});

module.exports = app;
