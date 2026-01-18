/* eslint-disable max-len */ // Temporarily disable max-len for specific lines if needed, or reformat

/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// Import necessary modules
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// REMOVED: const {setGlobalOptions} = require("firebase-functions/v1");

// Initialize Firebase Admin SDK
admin.initializeApp();

// REMOVED: setGlobalOptions({ maxInstances: 10 });

// --- createUser FUNCTION ---
exports.createUser = functions.https.onCall(async (data, context) => {
  // --- 1. Authentication & Permission Check ---
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Admin user must be logged in to create users.",
    );
  }
  const adminUid = context.auth.uid;
  const adminClaims = context.auth.token || {};
  const adminRole = adminClaims.role;
  console.log(`User creation request by admin: ${adminUid} ` +
              `(Role: ${adminRole})`);
  console.log("Data received:", data);

  const {
    registerNumber, name, password, roleToAssign, campusId, cohortId,
  } = data;
  if (!registerNumber || !name || !password ||
      !roleToAssign || !campusId || !cohortId) {
    throw new functions.https.HttpsError(
        "invalid-argument", "Missing required user information.",
    );
  }
  if (password.length < 6) {
    throw new functions.https.HttpsError(
        "invalid-argument", "Password must be at least 6 characters.",
    );
  }

  // --- 2. Permission Logic (Crucial!) ---
  let canAssignRole = false;
  const allowedCampusHeadRoles = ["CohortRep", "Volunteer"];
  const allowedOverallHeadRoles = ["CampusHead", "CohortRep", "Volunteer"];

  if (adminRole === "OverallHead") {
    canAssignRole = allowedOverallHeadRoles.includes(roleToAssign);
  } else if (adminRole === "CampusHead") {
    canAssignRole = allowedCampusHeadRoles.includes(roleToAssign);
    if (campusId !== adminClaims.campusId) {
      throw new functions.https.HttpsError(
          "permission-denied",
          "Campus Heads can only assign users to their own campus.",
      );
    }
  } else if (adminRole === "CohortRep") {
    canAssignRole = (roleToAssign === "Volunteer");
    if (campusId !== adminClaims.campusId ||
        cohortId !== adminClaims.cohortId) {
      throw new functions.https.HttpsError(
          "permission-denied",
          "Cohort Reps can only assign users to their own cohort.",
      );
    }
  }

  if (!canAssignRole) {
    console.error(`Admin role '${adminRole}' tried to assign ` +
                  `unauthorized role '${roleToAssign}'.`);
    throw new functions.https.HttpsError(
        "permission-denied",
        `Your role (${adminRole}) cannot assign the role: ${roleToAssign}.`,
    );
  }

  // --- 3. Create Firebase Auth User ---
  const email = `${registerNumber}@csa.app`;
  let newUserRecord;
  try {
    console.log(`Attempting to create Auth user: ${email}`);
    newUserRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
    });
    console.log(`Successfully created Auth user: ${newUserRecord.uid}`);
  } catch (error) {
    console.error("Error creating Auth user:", error);
    if (error.code === "auth/email-already-exists") {
      throw new functions.https.HttpsError(
          "already-exists",
          `An account already exists for register number ${registerNumber}.`,
      );
    }
    throw new functions.https.HttpsError(
        "internal", "Failed to create user account.", error.message,
    );
  }

  // --- 4. Set Custom Claims for the NEW User ---
  const newUserId = newUserRecord.uid;
  const claimsToSet = {
    role: roleToAssign,
    campusId: campusId,
    // Only add cohortId if it exists/is relevant
    ...(cohortId && {cohortId: cohortId}),
  };

  try {
    console.log(`Setting claims for ${newUserId}:`, claimsToSet);
    await admin.auth().setCustomUserClaims(newUserId, claimsToSet);
    console.log("Claims set successfully.");
  } catch (error) {
    console.error(`Error setting claims for ${newUserId}:`, error);
    throw new functions.https.HttpsError(
        "internal",
        "User account created, but failed to set permissions.", error.message,
    );
  }

  // --- 5. Create Firestore User Document ---
  const userDocRef = admin.firestore().collection("users").doc(newUserId);
  const userDocData = {
    registerNumber: registerNumber,
    name: name,
    email: email,
    role: roleToAssign,
    campusId: campusId,
    cohortId: cohortId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    console.log(`Creating Firestore document for ${newUserId}:`, userDocData);
    await userDocRef.set(userDocData);
    console.log("Firestore document created successfully.");
  } catch (error) {
    console.error(`Error creating Firestore document for ${newUserId}:`, error);
    throw new functions.https.HttpsError(
        "internal",
        "User account created, but failed to save user details.", error.message,
    );
  }

  // --- 6. Success ---
  console.log(`User ${newUserId} created successfully ` +
              `with role ${roleToAssign}.`);
  return {
    success: true,
    message: `User ${name} (${roleToAssign}) created successfully.`,
    userId: newUserId,
  };
}); // End of exports.createUser
