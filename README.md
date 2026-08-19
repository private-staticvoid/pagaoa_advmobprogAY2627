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
