import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  db,
  requireUser,
  userTier,
  isMember,
  assertButtonQuota,
  encodeSecret,
  decodeSecret,
  randomCode,
  SecretBundle,
} from "./lib";
import * as admin from "firebase-admin";

setGlobalOptions({ region: "us-central1", maxInstances: 20 });

type ButtonMeta = {
  id: string;
  label: string;
  iconName: string;
  method: string;
  timeoutMs: number;
  requiresConfirmation: boolean;
  sortOrder: number;
};

export const upsertButton = onCall(async (request) => {
  const uid = await requireUser(request.auth?.uid);
  const ownerId = String(request.data.ownerId || uid);
  const deckId = String(request.data.deckId || "");
  const button = request.data.button as ButtonMeta;
  const secret = request.data.secret as SecretBundle;
  if (!deckId || !button?.id) {
    throw new HttpsError("invalid-argument", "Deck and button are required.");
  }
  if (uid !== ownerId) {
    throw new HttpsError("permission-denied", "Only the owner can bind hooks.");
  }
  await assertButtonQuota(ownerId, deckId, button.id);
  if (!secret?.url) {
    throw new HttpsError("invalid-argument", "Webhook URL is required.");
  }
  const encrypted = encodeSecret({
    url: secret.url,
    headers: secret.headers || {},
    body: secret.body || "",
    method: secret.method || button.method || "POST",
  });
  const ref = db
    .collection("users")
    .doc(ownerId)
    .collection("decks")
    .doc(deckId)
    .collection("buttons")
    .doc(button.id);
  await ref.set(
    {
      id: button.id,
      label: button.label,
      iconName: button.iconName,
      method: secret.method || button.method || "POST",
      timeoutMs: button.timeoutMs || 15000,
      requiresConfirmation: Boolean(button.requiresConfirmation),
      sortOrder: button.sortOrder || 0,
      webhookUrl: encrypted,
      headers: {},
      body: "",
      isEncrypted: true,
      lastStatus: "idle",
    },
    { merge: true }
  );
  return { webhookUrl: encrypted };
});

export const getButtonSecret = onCall(async (request) => {
  const uid = await requireUser(request.auth?.uid);
  const ownerId = String(request.data.ownerId || uid);
  const deckId = String(request.data.deckId || "");
  const buttonId = String(request.data.buttonId || "");
  if (uid !== ownerId) {
    throw new HttpsError("permission-denied", "Secrets stay with the owner.");
  }
  const snap = await db
    .collection("users")
    .doc(ownerId)
    .collection("decks")
    .doc(deckId)
    .collection("buttons")
    .doc(buttonId)
    .get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Command not found.");
  }
  const data = snap.data() || {};
  const secret = decodeSecret(String(data.webhookUrl || ""));
  return secret;
});

export const triggerDeckButton = onCall(async (request) => {
  const uid = await requireUser(request.auth?.uid);
  return executeTrigger(
    uid,
    String(request.data.ownerId || uid),
    String(request.data.deckId || ""),
    String(request.data.buttonId || "")
  );
});

export const triggerDeckButtonHttp = onRequest({ cors: true }, async (req, res) => {
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({ error: "POST only" });
    return;
  }
  try {
    const header = String(req.headers.authorization || "");
    const token = header.replace(/^Bearer\s+/i, "");
    if (!token) {
      res.status(401).json({ error: "Missing token" });
      return;
    }
    const decoded = await admin.auth().verifyIdToken(token);
    const body = req.body || {};
    const result = await executeTrigger(
      decoded.uid,
      String(body.ownerId || decoded.uid),
      String(body.deckId || ""),
      String(body.buttonId || "")
    );
    res.status(200).json(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Trigger failed";
    res.status(400).json({ error: message });
  }
});

export const runExecutionProfile = onCall(async (request) => {
  const uid = await requireUser(request.auth?.uid);
  const ownerId = String(request.data.ownerId || uid);
  const deckId = String(request.data.deckId || "");
  const profileId = String(request.data.profileId || "");
  if ((await userTier(uid)) !== "premium" && (await userTier(ownerId)) !== "premium") {
    throw new HttpsError("permission-denied", "Flows require premium.");
  }
  if (!(await isMember(ownerId, deckId, uid))) {
    throw new HttpsError("permission-denied", "No access to this deck.");
  }
  const snap = await db
    .collection("users")
    .doc(ownerId)
    .collection("decks")
    .doc(deckId)
    .collection("profiles")
    .doc(profileId)
    .get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Flow not found.");
  }
  const profile = snap.data() || {};
  const steps = (profile.steps || []) as Array<{ buttonId: string; delaySeconds: number }>;
  const results = [];
  for (const step of steps) {
    if (step.delaySeconds) {
      await sleep(step.delaySeconds * 1000);
    }
    results.push(await executeTrigger(uid, ownerId, deckId, step.buttonId));
  }
  await snap.ref.set({ lastRunAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  return { results };
});

export const createInvite = onCall(async (request) => {
  const uid = await requireUser(request.auth?.uid);
  if ((await userTier(uid)) !== "premium") {
    throw new HttpsError("permission-denied", "Team sync requires premium.");
  }
  const deckId = String(request.data.deckId || "");
  const deckName = String(request.data.deckName || "Deck");
  const code = randomCode();
  const invite = {
    id: code,
    code,
    ownerId: uid,
    deckId,
    deckName,
    status: "active",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection("inviteCodes").doc(code).set(invite);
  await db.collection("users").doc(uid).collection("invites").doc(code).set(invite);
  return { code, ownerId: uid, deckId };
});

export const joinDeck = onCall(async (request) => {
  const uid = await requireUser(request.auth?.uid);
  const code = String(request.data.code || "").toUpperCase();
  const snap = await db.collection("inviteCodes").doc(code).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Invite code is invalid.");
  }
  const invite = snap.data() || {};
  if (invite.status !== "active") {
    throw new HttpsError("failed-precondition", "Invite is no longer active.");
  }
  const ownerId = String(invite.ownerId);
  const deckId = String(invite.deckId);
  const userSnap = await db.collection("users").doc(uid).get();
  const user = userSnap.data() || {};
  await db
    .collection("users")
    .doc(ownerId)
    .collection("decks")
    .doc(deckId)
    .collection("members")
    .doc(uid)
    .set({
      id: uid,
      email: user.email || "",
      displayName: user.displayName || "Operator",
      role: "operator",
      invitedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  await db
    .collection("users")
    .doc(uid)
    .collection("sharedDecks")
    .doc(deckId)
    .set({
      id: deckId,
      ownerId,
      deckId,
      role: "operator",
      deckName: invite.deckName || "Deck",
    });
  return { ok: true };
});

export const syncPremium = onCall(async (request) => {
  const uid = await requireUser(request.auth?.uid);
  const tier = request.data.premium ? "premium" : "free";
  await db.collection("users").doc(uid).set(
    {
      tier,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return { tier };
});

async function executeTrigger(
  uid: string,
  ownerId: string,
  deckId: string,
  buttonId: string
): Promise<Record<string, unknown>> {
  if (!deckId || !buttonId) {
    throw new HttpsError("invalid-argument", "Deck and button are required.");
  }
  if (!(await isMember(ownerId, deckId, uid))) {
    throw new HttpsError("permission-denied", "No access to this deck.");
  }
  const deckRef = db.collection("users").doc(ownerId).collection("decks").doc(deckId);
  const buttonRef = deckRef.collection("buttons").doc(buttonId);
  const [deckSnap, buttonSnap] = await Promise.all([deckRef.get(), buttonRef.get()]);
  if (!deckSnap.exists || !buttonSnap.exists) {
    throw new HttpsError("not-found", "Command not found.");
  }
  const deck = deckSnap.data() || {};
  const button = buttonSnap.data() || {};
  const secret = decodeSecret(String(button.webhookUrl || ""));
  if (!secret.url) {
    throw new HttpsError("failed-precondition", "This command has no webhook bound.");
  }
  const started = Date.now();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), Number(button.timeoutMs || 15000));
  let statusCode = 0;
  let bodyText = "";
  let status: "succeeded" | "failed" = "succeeded";
  try {
    const response = await fetch(secret.url, {
      method: secret.method || "POST",
      headers: {
        "User-Agent": "Hangar/1.0",
        ...(secret.headers || {}),
      },
      body: secret.method === "GET" ? undefined : secret.body || undefined,
      signal: controller.signal,
    });
    statusCode = response.status;
    bodyText = (await response.text()).slice(0, 400);
    if (statusCode < 200 || statusCode >= 300) {
      status = "failed";
    }
  } catch (error) {
    status = "failed";
    bodyText = error instanceof Error ? error.message : "Network fault";
  } finally {
    clearTimeout(timeout);
  }
  const durationMs = Date.now() - started;
  const event = {
    id: db.collection("_").doc().id,
    deckId,
    deckName: deck.name || "Deck",
    buttonId,
    buttonLabel: button.label || "Command",
    status,
    statusCode,
    durationMs,
    message: bodyText,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    provider: deck.provider || "custom",
  };
  await db.collection("users").doc(uid).collection("activity").doc(event.id).set(event);
  if (uid !== ownerId) {
    await db.collection("users").doc(ownerId).collection("activity").doc(event.id).set(event);
  }
  await buttonRef.set(
    {
      lastTriggered: admin.firestore.FieldValue.serverTimestamp(),
      lastStatus: status,
    },
    { merge: true }
  );
  await deckRef.set(
    {
      lastTriggeredAt: admin.firestore.FieldValue.serverTimestamp(),
      lastStatus: status,
    },
    { merge: true }
  );
  if (status === "failed") {
    throw new HttpsError("internal", `Hook returned ${statusCode || "fault"}: ${bodyText}`);
  }
  return {
    status,
    statusCode,
    durationMs,
    message: bodyText || "Command dispatched",
    buttonLabel: button.label || "Command",
    deckName: deck.name || "Deck",
  };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
