// lib/data/health_ids.dart

class HealthID {
  static const String systemHealthScore = 'sys_health_score';
  // ============================================================
  // 1. CORE VITALS (Primary Inputs)
  // ============================================================
  // Renamed 'temp' to 'bodyTemp' to avoid conflict with Environmental Ambient Temp
  static const String bodyTemp = 'body_temp'; 
  static const String heartRate = 'hr';
  static const String bloodPressure = 'bp'; // Stores composite "120/80"
  static const String spo2 = 'spo2';
  static const String respRate = 'resp';
  static const String weight = 'weight';
  static const String height = 'height';
  
  // REMOVED: 'bmi' (Derived from weight & height)

  // ============================================================
  // 2. DIABETES & METABOLISM
  // ============================================================
  static const String glucose = 'glu';      // Single stream for Fasting/Random/Post-Meal
  static const String hba1c = 'hba1c';      // 3-month average marker

  // ============================================================
  // 3. HEART HEALTH (Lipid Profile)
  // ============================================================
  static const String cholesterol = 'chol'; // Total Cholesterol
  static const String hdl = 'hdl';          
  static const String ldl = 'ldl';          
  static const String triglycerides = 'trig';

  // ============================================================
  // 4. BLOOD COUNT (CBC - Measured Values Only)
  // ============================================================
  static const String hemoglobin = 'hgb';
  static const String rbc = 'rbc';
  static const String wbc = 'wbc';
  static const String platelets = 'plt';
  
  // REMOVED: mcv, mch, mchc (Calculated indices)
  // REMOVED: pcv/hematocrit (Often calculated from RBC * MCV)
  
  // Differential Count (Percentages of WBC) - Kept as they are specific lab measures
  static const String neutrophils = 'neu';
  static const String lymphocytes = 'lym';
  static const String monocytes = 'mon';
  static const String eosinophils = 'eos';
  static const String basophils = 'bas';

  // ============================================================
  // 5. ORGAN FUNCTION (Kidney & Liver)
  // ============================================================
  static const String creatinine = 'creat';
  static const String urea = 'urea';
  static const String uricAcid = 'uric';
  static const String sgot = 'sgot';       // AST
  static const String sgpt = 'sgpt';       // ALT
  static const String bilirubin = 'bili';

  // ============================================================
  // 6. THYROID PROFILE
  // ============================================================
  static const String tsh = 'tsh';
  static const String t3 = 't3';
  static const String t4 = 't4';
  
  // ============================================================
  // 7. LIFESTYLE & ACTIVITY
  // ============================================================
  static const String steps = 'steps';
  static const String distance = 'dist';
  static const String sleep = 'sleep';
  static const String calories = 'cal';
  static const String water = 'water';
}