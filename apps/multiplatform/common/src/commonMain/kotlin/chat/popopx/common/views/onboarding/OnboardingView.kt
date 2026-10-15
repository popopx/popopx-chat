package chat.popopx.common.views.onboarding

enum class OnboardingStage {
  Step1_POPOPXInfo,
  Step2_CreateProfile,
  LinkAMobile,
  Step2_5_SetupDatabasePassphrase,
  Step3_ChooseServerOperators,
  Step3_CreatePOPOPXAddress, // deprecated
  Step4_SetNotificationsMode, // deprecated
  Step4_NetworkCommitments,
  OnboardingComplete
}
