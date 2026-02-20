class SignupDraft {
  // Step 1
  String firstName = "";
  String lastName = "";
  String gender = "";
  String city = "";
  String country = "";
  String phone = "";
  String email = "";
  String password = "";
  String lookingFor = "";

  // Step 2
  DateTime? birthdate;
  String? photo1Path; // obligatoire (chemin local)
  String? photo2Path; // optionnel
  String? photo3Path; // optionnel
  String bio = ""; // optionnel
  bool acceptedTerms = false; // obligatoire

  // Abonnement & droits (par défaut)
  String plan = "gratuit"; // gratuit | premium | ultra
  int swipesPerDay = 20;
  int superLikesPerDay = 1;
  int rewindsPerDay = 1;

  bool emailVerified = false;

  void applyPlanDefaults(String newPlan) {
    plan = newPlan;

    if (newPlan == "gratuit") {
      swipesPerDay = 20;
      superLikesPerDay = 1;
      rewindsPerDay = 1; // ✅ 1 retour/jour
    } else if (newPlan == "premium") {
      swipesPerDay = 999999; // illimité
      superLikesPerDay = 5;
      rewindsPerDay = 5; // ✅ 5 retours/jour
    } else if (newPlan == "ultra") {
      swipesPerDay = 999999; // illimité
      superLikesPerDay = 999999; // illimité
      rewindsPerDay = 999999; // ✅ retours illimités
    }
  }
}