// Google Play listing of the Android app (ADR-0067, #1141).
//
// The installation page shows the Google Play section only once the app is
// live in production on Google Play (a personal developer account needs a
// closed test first, #1142). Until then the page shows Obtainium alone.
// Set to true in the PR that publishes the link.
export const googlePlayListed = false;

// The application ID of the release build (app/android/app/build.gradle.kts).
export const googlePlayAppId = 'app.setding';

export const googlePlayUrl = `https://play.google.com/store/apps/details?id=${googlePlayAppId}`;
