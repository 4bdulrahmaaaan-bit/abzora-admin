const crypto = require('crypto');
const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const Razorpay = require('razorpay');

admin.initializeApp();

const db = admin.firestore();

function buildAllowedCorsOrigins() {
  // Security hardening: explicit origin allowlist for browser calls.
  const configured = String(process.env.CORS_ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  if (configured.length > 0) {
    return configured;
  }
  return [
    'http://localhost:3000',
    'http://localhost:5173',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:5173',
  ];
}

const REQUEST_OPTIONS = {
  cors: buildAllowedCorsOrigins(),
};

function safeSignatureEquals(expectedHex, providedHex) {
  // Security hardening: constant-time signature comparison to reduce timing leaks.
  const expectedBuffer = Buffer.from(String(expectedHex || '').trim(), 'utf8');
  const providedBuffer = Buffer.from(String(providedHex || '').trim(), 'utf8');
  if (!expectedBuffer.length || expectedBuffer.length !== providedBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(expectedBuffer, providedBuffer);
}

function getRazorpayClient() {
  const keyId = process.env.RAZORPAY_KEY_ID || '';
  const keySecret = process.env.RAZORPAY_KEY_SECRET || '';
  if (!keyId || !keySecret) {
    throw new Error('Razorpay server credentials are missing.');
  }
  return new Razorpay({
    key_id: keyId,
    key_secret: keySecret,
  });
}

async function authenticate(request, response) {
  const authHeader = request.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) {
    response.status(401).json({ message: 'Missing auth token.' });
    return null;
  }
  const idToken = authHeader.replace('Bearer ', '').trim();
  try {
    // Security hardening: enforce revocation checks for Firebase ID tokens.
    return await admin.auth().verifyIdToken(idToken, true);
  } catch (error) {
    logger.error('Auth verification failed', error);
    response.status(401).json({ message: 'Invalid auth token.' });
    return null;
  }
}

exports.createCardSetupOrder = onRequest(REQUEST_OPTIONS, async (request, response) => {
  if (request.method !== 'POST') {
    response.status(405).json({ message: 'Method not allowed.' });
    return;
  }

  const decoded = await authenticate(request, response);
  if (!decoded) {
    return;
  }

  const userId = request.body?.userId?.toString() || decoded.uid;
  if (userId !== decoded.uid) {
    response.status(403).json({ message: 'User mismatch.' });
    return;
  }

  try {
    const razorpay = getRazorpayClient();
    const order = await razorpay.orders.create({
      amount: 100,
      currency: 'INR',
      receipt: `card_setup_${userId}_${Date.now()}`,
      notes: {
        flow: 'card_vault',
        userId,
      },
    });

    response.status(200).json({
      orderId: order.id,
      amount: 1,
      currency: order.currency || 'INR',
      receipt: order.receipt,
    });
  } catch (error) {
    logger.error('createCardSetupOrder failed', error);
    response.status(500).json({ message: 'Could not create Razorpay setup order.' });
  }
});

exports.createCheckoutOrder = onRequest(REQUEST_OPTIONS, async (request, response) => {
  if (request.method !== 'POST') {
    response.status(405).json({ message: 'Method not allowed.' });
    return;
  }

  const decoded = await authenticate(request, response);
  if (!decoded) {
    return;
  }

  const userId = request.body?.userId?.toString() || decoded.uid;
  const amount = Number(request.body?.amount || 0);
  const currency = request.body?.currency?.toString() || 'INR';
  const description = request.body?.description?.toString() || 'Order Payment';
  if (userId !== decoded.uid) {
    response.status(403).json({ message: 'User mismatch.' });
    return;
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    response.status(400).json({ message: 'Invalid order amount.' });
    return;
  }

  try {
    const razorpay = getRazorpayClient();
    const order = await razorpay.orders.create({
      amount: Math.round(amount),
      currency,
      receipt: `checkout_${userId}_${Date.now()}`,
      notes: {
        flow: 'checkout',
        userId,
        description,
      },
    });

    response.status(200).json({
      orderId: order.id,
      amount: order.amount,
      currency: order.currency || currency,
      receipt: order.receipt,
    });
  } catch (error) {
    logger.error('createCheckoutOrder failed', error);
    response.status(500).json({ message: 'Could not create Razorpay checkout order.' });
  }
});

exports.verifyPayment = onRequest(REQUEST_OPTIONS, async (request, response) => {
  if (request.method !== 'POST') {
    response.status(405).json({ message: 'Method not allowed.' });
    return;
  }

  const decoded = await authenticate(request, response);
  if (!decoded) {
    return;
  }

  const paymentId = request.body?.paymentId?.toString() || '';
  const orderId = request.body?.razorpayOrderId?.toString() || '';
  const signature = request.body?.signature?.toString() || '';
  if (!paymentId || !orderId || !signature) {
    response.status(400).json({ message: 'Missing payment verification fields.' });
    return;
  }

  try {
    const keySecret = process.env.RAZORPAY_KEY_SECRET || '';
    if (!keySecret) {
      response.status(500).json({ message: 'Razorpay secret is not configured.' });
      return;
    }

    const expected = crypto
      .createHmac('sha256', keySecret)
      .update(`${orderId}|${paymentId}`)
      .digest('hex');

    if (!safeSignatureEquals(expected, signature)) {
      response.status(400).json({
        verified: false,
        message: 'Payment signature verification failed.',
      });
      return;
    }

    const razorpay = getRazorpayClient();
    const payment = await razorpay.payments.fetch(paymentId);
    const status = payment?.status?.toString() ?? '';
    const verified = status == 'captured' || status == 'authorized';

    response.status(200).json({
      verified,
      paymentId,
      orderId,
      status,
      method: payment?.method?.toString(),
      amount: payment?.amount ?? null,
      message: verified ? 'Payment verified successfully.' : 'Payment is not captured yet.',
    });
  } catch (error) {
    logger.error('verifyPayment failed', error);
    response.status(500).json({
      verified: false,
      message: 'Could not verify payment right now.',
    });
  }
});

exports.finalizeCardSetup = onRequest(REQUEST_OPTIONS, async (request, response) => {
  if (request.method !== 'POST') {
    response.status(405).json({ message: 'Method not allowed.' });
    return;
  }

  const decoded = await authenticate(request, response);
  if (!decoded) {
    return;
  }

  const userId = request.body?.userId?.toString() || decoded.uid;
  const paymentId = request.body?.paymentId?.toString() || '';
  const orderId = request.body?.razorpayOrderId?.toString() || '';
  const signature = request.body?.signature?.toString() || '';
  if (userId !== decoded.uid) {
    response.status(403).json({ message: 'User mismatch.' });
    return;
  }
  if (!paymentId || !orderId || !signature) {
    response.status(400).json({ message: 'Missing payment verification fields.' });
    return;
  }

  try {
    const keySecret = process.env.RAZORPAY_KEY_SECRET || '';
    const expected = crypto
      .createHmac('sha256', keySecret)
      .update(`${orderId}|${paymentId}`)
      .digest('hex');
    if (!safeSignatureEquals(expected, signature)) {
      response.status(400).json({ message: 'Payment signature verification failed.' });
      return;
    }

    const razorpay = getRazorpayClient();
    const payment = await razorpay.payments.fetch(paymentId);
    if (!payment || payment.status !== 'captured') {
      response.status(400).json({ message: 'Payment is not captured.' });
      return;
    }

    const token =
      payment.token_id ||
      payment.card_id ||
      payment.card?.token_id ||
      payment.token?.id ||
      '';
    const last4 =
      payment.card?.last4 ||
      payment.card?.last4_digits ||
      payment.last4 ||
      '0000';
    const cardType =
      payment.card?.network ||
      payment.card?.issuer ||
      payment.method ||
      'Card';

    if (!token) {
      response.status(409).json({
        message: 'Razorpay payment succeeded, but no reusable token was returned. Enable tokenization / saved cards on the Razorpay account before using this flow.',
      });
      return;
    }

    const cardRef = db.collection('user_cards').doc();
    await cardRef.set({
      userId,
      token,
      last4,
      cardType: String(cardType).toUpperCase(),
      paymentId,
      orderId,
      gatewayCustomerId: payment.customer_id || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    response.status(200).json({
      cardId: cardRef.id,
      last4,
      cardType: String(cardType).toUpperCase(),
      gatewayCustomerId: payment.customer_id || null,
    });
  } catch (error) {
    logger.error('finalizeCardSetup failed', error);
    response.status(500).json({ message: 'Could not finalize saved card setup.' });
  }
});
