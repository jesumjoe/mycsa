import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface NewUserData {
  registerNumber: string;
  name: string;
  password: string;
  roleToAssign: string;
  campusId: string;
  cohorts: string[];
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method Not Allowed" }),
      { status: 405, headers: { "Content-Type": "application/json" } },
    );
  }

  try {
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const userData: NewUserData = await req.json();
    const {
      registerNumber,
      name,
      password,
      roleToAssign,
      campusId,
      cohorts,
    } = userData;

    // --- START FIX: Updated Validation Logic ---

    // 1. Basic validation (cohorts can be empty, but not null/undefined)
    if (!registerNumber || !name || !password || !roleToAssign || !campusId || cohorts == null) {
      throw new Error("Missing required user information.");
    }

    // 2. Role-specific cohort validation
    if (roleToAssign === "Volunteer" || roleToAssign === "CohortRep") {
      if (cohorts.length === 0) {
        // Volunteers and Cohort Reps MUST have at least one cohort
        throw new Error(`A ${roleToAssign} must be assigned to at least one cohort.`);
      }
    }
    // (Campus Heads and Overall Heads are allowed to have cohorts.length === 0)

    // 3. Password validation
    if (password.length < 6) {
      throw new Error("Password must be at least 6 characters.");
    }
    // --- END FIX ---


    // 3. Create Supabase Auth User
    const email = `${registerNumber}@csa.app`;
    console.log(`Attempting to create Auth user: ${email}`);
    const { data: authData, error: authError } = await adminClient.auth.admin
      .createUser({
        email: email,
        password: password,
        email_confirm: true,
        user_metadata: { name: name },
      });

    if (authError) {
      console.error("Error creating Auth user:", authError.message);
      if (authError.message.includes("unique constraint")) {
         return new Response(
          JSON.stringify({ error: `An account already exists for register number ${registerNumber}.` }),
          { status: 409, headers: { "Content-Type": "application/json" } },
        );
      }
      throw authError;
    }
    
    const newUserId = authData.user.id;
    console.log(`Successfully created Auth user: ${newUserId}`);

    // 4. Set Custom Claims (app_metadata)
    const claimsToSet = {
      role: roleToAssign,
      campusId: campusId,
      cohorts: cohorts, // Store the array (will be [] for Campus Head)
    };

    const { data: userUpdateData, error: userUpdateError } = await adminClient.auth.admin
      .updateUserById(newUserId, { app_metadata: claimsToSet });
      
    if (userUpdateError) {
       console.error(`Error setting claims for ${newUserId}:`, userUpdateError.message);
       await adminClient.auth.admin.deleteUser(newUserId); // Clean up failed user
       throw new Error("User account created, but failed to set permissions.");
    }
    
    console.log("Claims set successfully.");

    // 5. Update the 'users' table row (created by the trigger)
    await new Promise(resolve => setTimeout(resolve, 1000)); // Wait for trigger

    const { data: dbData, error: dbError } = await adminClient
      .from("users")
      .update({
        role: roleToAssign,
        campusId: campusId,
        cohorts: cohorts, // Save the array here too
        name: name,
      })
      .eq("id", newUserId)
      .select();

    if (dbError) {
      console.error(`Error updating user profile in DB for ${newUserId}:`, dbError.message);
      throw new Error("User account created, but failed to save user details to database.");
    }
    
    console.log("Database profile updated successfully:", dbData);

    // 6. Success
    return new Response(
      JSON.stringify({
        success: true,
        message: `User ${name} (${roleToAssign}) created successfully.`,
        userId: newUserId,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    // Catch-all Error Handler
    console.error("Internal Server Error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message || "An unexpected error occurred." }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});