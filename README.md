# Pokémon Explorer

## App Name & Description

**Pokémon Explorer** is a Flutter mobile app that allows users to search for Pokémon using the PokeAPI, view Pokémon information and artwork, and save favorite Pokémon locally for offline viewing.

---

## API Used

This app uses the **PokeAPI** public REST API.

Website: https://pokeapi.co/

Example endpoint:

https://pokeapi.co/api/v2/pokemon/pikachu

Example list endpoint:

https://pokeapi.co/api/v2/pokemon?limit=20&offset=0

The app performs HTTP GET requests to retrieve Pokémon data and parses the JSON responses into Dart model objects.

---

## Storage Strategy

### SQLite (sqflite)

SQLite is used to store the user's saved favorite Pokémon because it is structured data that must persist between app launches.

Each saved Pokémon includes:
- Pokémon ID
- Name
- Image URL
- User note
- Date saved

### Shared Preferences

Shared Preferences is used for lightweight application settings:
- Last Pokémon search query
- Selected theme mode (Light, Dark, or System)

---

## Data Format

Each saved Pokémon is stored as a row in the SQLite table:

| Column | Type | Description |
|----------|----------|----------|
| dbId | INTEGER | Auto-increment primary key |
| pokemonId | INTEGER | Pokémon ID from PokeAPI |
| name | TEXT | Pokémon name |
| spriteUrl | TEXT | Pokémon image URL |
| note | TEXT | User-created note |
| savedAt | TEXT | Date/time saved |

---

## How to Run the App

### Prerequisites

- Flutter SDK
- Android Studio or VS Code
- Android Emulator or physical Android device

### Setup

git clone (https://github.com/KingHimry/Solo3.git)
cd pokemon_explorer

flutter pub get

flutter devices

flutter run

### Android Permission

Add to:

android/app/src/main/AndroidManifest.xml

<uses-permission android:name="android.permission.INTERNET"/>

---

## How to Test Persistence

1. Launch the app.
2. Search for a Pokémon (example: Pikachu).
3. Press Save.
4. Open the Saved tab and verify the Pokémon appears.
5. Completely close the application.
6. Reopen the application.
7. Navigate to the Saved tab.
8. Verify the saved Pokémon is still present.

---

## Edge Cases

### 1. Invalid Pokémon Name

The app displays a user-friendly empty state instead of crashing.

### 2. No Internet Connection

The app displays an error screen with a Retry button.

---

## Features Demonstrated

- HTTP GET requests using PokeAPI
- JSON parsing into Dart model classes
- Loading spinner during network requests
- Error state with Retry button
- Empty state handling
- Search functionality
- SQLite local persistence
- Shared Preferences settings storage
- Save favorites from API results
- Delete individual favorites
- Clear All saved favorites
- Persistent data loading on app startup
- SnackBar feedback for user actions
- Material Design 3 user interface
