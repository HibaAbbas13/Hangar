import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { decrypt, encrypt, randomCode } from "./crypto";

admin.initializeApp();
export const db = admin.firestore();

export const FREE_DECKS = 1;
export const FREE_BUTTONS = 3;

export type SecretBundle = {
  url: string;
  headers: Record<string, string>;
  body: string;
  method: string;
};

export async function requireUser(uid?: string): Promise<string> {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return uid;
}

export async function userTier(uid: string): Promise<"free" | "premium"> {
  const snap = await db.collection("users").doc(uid).get();
  const tier = (snap.data()?.tier as string) || "free";
  return tier === "premium" ? "premium" : "free";
}

export function canAccessDeck(uid: string, ownerId: string, isMember: boolean): void {
  if (uid !== ownerId && !isMember) {
    throw new HttpsError("permission-denied", "This deck is outside your flight path.");
  }
}

export async function isMember(ownerId: string, deckId: string, uid: string): Promise<boolean> {
  if (uid === ownerId) return true;
  const snap = await db
    .collection("users")
    .doc(ownerId)
    .collection("decks")
    .doc(deckId)
    .collection("members")
    .doc(uid)
    .get();
  return snap.exists;
}

export async function assertDeckQuota(uid: string): Promise<void> {
  if ((await userTier(uid)) === "premium") return;
  const snap = await db.collection("users").doc(uid).collection("decks").get();
  if (snap.size >= FREE_DECKS) {
    throw new HttpsError("resource-exhausted", "Premium is required for additional decks.");
  }
}

export async function assertButtonQuota(ownerId: string, deckId: string, buttonId: string): Promise<void> {
  if ((await userTier(ownerId)) === "premium") return;
  const snap = await db
    .collection("users")
    .doc(ownerId)
    .collection("decks")
    .doc(deckId)
    .collection("buttons")
    .get();
  const exists = snap.docs.some((d) => d.id === buttonId);
  if (!exists && snap.size >= FREE_BUTTONS) {
    throw new HttpsError("resource-exhausted", "Free decks hold 3 commands.");
  }
}

export function encodeSecret(secret: SecretBundle): string {
  return encrypt(JSON.stringify(secret));
}

export function decodeSecret(payload: string): SecretBundle {
  const parsed = JSON.parse(decrypt(payload)) as SecretBundle;
  return {
    url: parsed.url,
    headers: parsed.headers || {},
    body: parsed.body || "",
    method: parsed.method || "POST",
  };
}

export { randomCode };
