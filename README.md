# Achilles Troy T. Pagaoa

## INF 231

## CTADMOBPL: Advanced Mobile Programming

This repository contains a Flutter project developed for the **Advanced Mobile Programming** course.

### Project Overview

The project focuses on advanced Flutter development topics, with an emphasis on **mobile-to-web transactions** and modern cross-platform application development.

## Lab Activity Instance

This repository serves as the workspace for laboratory activities, exercises, and implementations completed throughout the course.

## Laboratory 1 Discussions

### Discussion 1: What is state management in Flutter?

State management in Flutter is the process of managing and controlling data that can change in an app. It keeps the UI updated whenever the state changes, such as changing themes, updating counters, or handling user input. It helps organize data and makes the app easier to maintain as it grows.

### Discussion 2: Discuss the differences between using setState and Provider

setState and Provider are both used for managing state in Flutter, but they are used in different situations.

setState is used for managing local or temporary state inside a single widget. It is simple and works well for small changes, such as updating a counter or changing a value on one page. However, the state cannot easily be shared with other widgets.

Provider is used for managing shared app state that needs to be accessed by multiple widgets. It separates the data logic from the UI and makes it easier to maintain larger applications, such as managing themes, user information, or app settings.

In short, setState is best for simple widget-level changes, while Provider is better for managing data shared across the application like light and dark mode in this application.

## Laboratory 2 Discussion

### Discuss how the Model, Service, and Screen interact with each other to render the API endpoint.

This app is split into three simple layers: Model → Service → Screen.

**Model (`product.dart`)** holds the data. It just describes what a product looks like (title, price, image, etc.) and converts raw JSON from the API into a proper `Product` object using `fromJson()`. If a field is missing, it just uses a default value instead of crashing.

**Service (`product_service.dart`)** talks to the API. It sends the request, gets the JSON response back, and converts it into a list of `Product` objects using the Model. This is the only part of the app that connects to the internet — the screens never do this directly.

**Screen (`product_screen.dart` / `product_detail_screen.dart`)** shows the data. It asks the Service for the product list once, then uses a `FutureBuilder` to display a loading spinner, an error message, or the actual product grid depending on what happens. When you tap a product, it doesn't call the API again — it just passes the same `Product` object to the details screen, which simply displays it.

In short: JSON never goes straight to the screen. It always flows like this: API → Model (converts JSON) → Service (fetches + returns data) → Screen (displays it). So the endpoint's JSON never touches the UI directly — it's always raw JSON → `Model.fromJson()` → Service returns typed Future → Screen's `FutureBuilder` renders it. Each layer has one job, which is what makes it easy to add the search bar (filtering typed `Product` objects in the screen, no service change needed) and the detail page (reusing the same `Product` object, no new endpoint needed).

### New design patterns introduced in this activity

1. **Repository/Service pattern** (already present, reinforced by reuse) — `ProductService` centralizes all data access behind a simple method (`getAllProducts()`). The screen doesn't know or care if data comes from a REST API, a local cache, or a mock — it just awaits a `Future<List<Product>>`. This is what let the detail screen and search feature be built without touching the service at all.

2. **Observer pattern via Provider/ChangeNotifier** — `ThemeProvider` extends `ChangeNotifier` and calls `notifyListeners()` on `toggleTheme()`. `MaterialApp` (via `context.watch<ThemeProvider>()`) and `SettingsPage` (via `context.watch`/`Provider.of`) are both observers that automatically rebuild when that state changes. This is why toggling the switch in Settings instantly re-themes the whole app without any manual navigation callbacks — although the settings screen also demonstrates a second, more manual observer-style pattern: returning `themeChanged` via `Navigator.pop(context, themeChanged)`, which is a value-based signal back to whoever pushed the route.

3. **Composition/Placeholder pattern for the nav** — instead of writing three different bespoke "not implemented" screens, `ComingSoonScreen` is one reusable widget parameterized by `label` and `icon`. This is a small instance of the Template/Strategy-ish reuse pattern — one component, multiple configurations, rather than duplicating layout code per tab.

4. **Local reactive filtering (search)** — rather than re-querying the API per keystroke (which would be slow and wasteful), the search feature keeps the full list in memory (`_allProducts`) and derives a `_filteredProducts` view via a `TextEditingController` listener plus `setState`. This is a simple derived-state pattern — one source of truth, transformed on demand, which keeps the API layer completely untouched by UI-level search logic.

## Laboratory 3 Discussion

### Discuss how the Cart model, services, and screen interact with each other to render the API endpoint going to the same detail_screen.dart. Discuss the updated design pattern in this activity. Also discuss how to use getById at the Cart endpoint.

**Cart model, service, and screen interaction:** The Cart model just holds the data structure, `CartService` is the one that actually fetches and parses the JSON from the API, and the screen calls that service (through a `FutureBuilder`) to display the carts — and since each cart item is really just a `Product` with a quantity, tapping it still routes to the same `ProductDetailScreen(product: product)` instead of building a whole new detail screen.

So overall, I'd say the biggest thing I took from this activity is that once you set up the model → service → screen pattern properly for one feature (Product), adding a similar feature (Cart) becomes a lot faster because you're just repeating the same structure, and you can even reuse screens like the detail screen across features as long as they depend on the same underlying model.

### New design patterns introduced in this activity

1. **Layered architecture reinforced across features** — this activity basically reinforced separating things into layers: model (data), service (API calls), and screen (UI/state), so the screen doesn't touch the API directly anymore. Reusing `ProductDetailScreen` for cart items shows that once a detail screen depends on a model instead of a specific source, it can be reused anywhere that model shows up.
2. **getById at the Cart endpoint** — to get a single cart, `CartService` calls `https://dummyjson.com/carts/{id}` and parses the response with `Cart.fromJson()`, so instead of fetching all carts and searching through them, we just ask for the one cart we already know the ID of.

## Laboratory 4 Discussion

### Discuss how the user model, services and screen interact with each other to render the API endpoint going to the profile_screen. Discuss the updated design pattern in this activity. Also discuss how to use the saved data in rendering the cart_screen by user id.

The user model, service, and screens each handle a different job. The user model, user.dart, just defines the shape of a user's data, id, username, email, token, and converts it to and from JSON. The user service is where the actual work happens, it calls the DummyJSON API to log in, builds the response into a user model, and saves it using shared preferences 2.5.5 so the session persists. The screens only handle UI, they call the service methods and display whatever comes back, they do not talk to the API or to storage directly.

For the flow going to profile screen, the splash screen first calls the user service to check shared preferences for a saved session, this is the persistent authentication from enhancement one. If a session exists, it skips sign in and goes straight to home with the saved user data attached. The profile screen then reads that same user model data, either passed through navigation or pulled again from the service, and displays it in its own custom UI, no repeated API call needed.

### Design Pattern

The pattern here is about separating them into their own files instead of putting logic inside one widget. Before, a screen might handle its own API calls and storage directly. Now the project adds dedicated files for each responsibility, splash screen.dart for the entry point and auth check, sign in screen.dart for login UI and logic, user service.dart for API calls and shared preferences, and user.dart as the model. Each screen only imports and uses the service it needs. This makes the code more organized, since adding or fixing something, like changing how login works, only means editing user service, not touching every screen that uses it.

### Rendering the Cart Screen by User ID

Since the user model is already saved in shared preferences after login, the cart screen can call the user service to get that saved data anytime, without logging in again. It then takes the user id from that model and uses it to filter or fetch only the cart items belonging to that user. So the flow is, shared preferences holds the last saved user, the user service reads it and returns the user id, and the cart screen uses that id to load the correct cart. This keeps each user's cart personal and consistent even after closing and reopening the app.

## Laboratory 5 Discussion

### Discuss the workflow for the DummyJSON and Firebase implementation, from signIn to signUp. What is the main idea of the UserService implementation? What are the benefits of the Firebase implementation in this application?

The app now supports two login backends, and the user picks one with a toggle on the sign in and sign up screens. Whichever one is used, the session is saved with a `LoginType` (`dummyJson` or `firebase`) so the rest of the app knows where the user came from.

**DummyJSON workflow.** On sign in, the user types a username and password and `UserService.loginUser()` sends `POST /auth/login`. DummyJSON returns the user plus an `accessToken` and `refreshToken`. Since the login response does not include age and phone, the service uses the new token to call `GET /auth/me` for the full profile. Everything is saved to SharedPreferences through `saveUserData()` and the user goes to home. On the next launch, the splash screen checks the saved token and tries `POST /auth/refresh` to get a fresh one. Sign up is the weak point: `POST /users/add` is only simulated. DummyJSON answers with a realistic new user and id, but never saves it, so that account can never log in. Only the seeded demo accounts (like `emilys`) work, and there is nothing real to update or delete, so the profile screen shows those accounts as read-only.

**Firebase workflow.** Sign up starts with the form (first name, last name, age, contact no., username, email, password), which is validated first, including a live password checklist (8+ characters, uppercase, lowercase, number, special character). `registerWithFirebase()` calls `createAccount()` (`createUserWithEmailAndPassword`), which creates a real account and signs the user in at the same time. The username is set with `updateDisplayName()`. Firebase Auth only stores email, password and display name, so the other fields are saved in a Cloud Firestore document at `users/{uid}`, using the same field names as DummyJSON (`firstName`, `age`, `phone`, ...) so one `User.fromJson()` can read both. The session is saved to SharedPreferences and the user goes straight to home. Sign in uses email and password with `signIn()`, then reads the Firestore profile and saves the session. On the next launch, the splash screen uses `authStateChanges()` to see if Firebase restored the user, then forces a token refresh with `getIdToken(true)`. If the account was deleted or disabled in the Firebase Console, the refresh fails and the app logs the user out. From the profile screen, a Firebase user can update the username, change the password (`resetPasswordFromCurrentPassword()`, which re-authenticates with the current password first), and delete the account (`deleteAccount()`, which re-authenticates, deletes the Firestore document, then deletes the user). Logout, from the profile screen or settings, calls `signOut()`, clears the saved session and token, and sends the user back to sign in.

|                                   | DummyJSON                                                              | Firebase                                                            |
| --------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Sign in                           | `POST /auth/login` with username                                       | `signInWithEmailAndPassword` with email                             |
| Sign up                           | `POST /users/add` (simulated, not saved)                               | `createUserWithEmailAndPassword` (real account) + Firestore profile |
| Token                             | `accessToken` / `refreshToken`, refreshed manually via `/auth/refresh` | ID token, refreshed automatically by the SDK                        |
| Session on device                 | SharedPreferences                                                      | Firebase SDK + SharedPreferences                                    |
| Update / change password / delete | Not possible (mock API)                                                | Supported                                                           |
| Data security                     | Public demo data                                                       | Passwords handled by Google, Firestore security rules               |

**Main idea of UserService.** `UserService` is the single gateway for everything about the user. The screens only call methods like `loginUser()`, `loginWithFirebase()`, `registerWithFirebase()`, `updateUsername()` or `logout()`. They never touch `http`, `FirebaseAuth`, Firestore or SharedPreferences directly. Both backends end in the same `saveUserData()` and the same `User` model, so the splash screen, profile screen and cart work the same no matter which backend was used. Adding Firebase in this lab did not require changing the cart code at all. If the app later switches to another backend, only `UserService` needs to change.

**Benefits of Firebase in this app.** Accounts are now real and persistent, instead of only a few shared demo users. Passwords are never stored by the app; Firebase handles them securely. Tokens refresh automatically, and features like re-authentication, password change and account deletion come built in, so we did not have to build our own server. Firestore security rules make sure each user can only read and write their own profile document. The Firebase Console also gives control from outside the app: disabling or deleting a user there logs them out the next time the app opens. All of this runs on the free Spark plan.

### Design Pattern

1. **Facade (UserService)** — one class hides the details of two different backends behind simple methods.
2. **LoginType as a switch between backends** — the enum is saved with the session, and the splash screen, profile screen and logout use it to pick the right behavior (for example, which details to show and whether account actions are available).
3. **Shared validation in `utils/`** — `validators.dart` holds every form rule and `auth_errors.dart` turns Firebase error codes into friendly messages, so no screen repeats that logic.
4. **Reusable widgets** — `password_requirements.dart` (live checklist) and `account_dialogs.dart` (update username, change password, delete account) keep the screens short and readable.

### Firestore security rules used

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```
