# 🎭 GuessMe - Multiplayer Headband Game

![GuessMe Banner](assets/images/banner.png)

## 🚀 Live Demo & Downloads

*   **🌐 Web Version**: Play directly in your browser at [guess-me-bfd58.web.app](https://guess-me-bfd58.web.app/)
*   **📱 Android APK**: The latest stable APK is available in the [Releases section](https://github.com/Gigiux6/GuessMe/releases) of this repository.

**GuessMe** is a vibrant, fun-filled multiplayer social game inspired by the classic "Who Am I?" or "Headband" games. Play with friends online in real-time, guess your secret identity, and enjoy a premium gaming experience built with Flutter and Firebase.

## 🚀 Main Features

*   **Real-time Multiplayer**: Join or create rooms instantly with a unique code.
*   **Multiple Game Modes**:
    *   🕒 **Timed Mode**: Race against the clock! Guess as many identities as possible to earn points and win. Includes a synchronized global timer for all players.
    *   🃏 **Classic Mode**: The traditional experience. Guess your identity one question at a time and be the last one standing!
    *   🛠️ **Custom Mode**: Create your own secret identities for your friends to guess!
*   **Smart Sync**: Shared timers and game states synchronized across all devices using Firebase Realtime Database.
*   **Multilingual Support**: Fully localized in **Italian, English, Spanish, German, and French**.
*   **Rich Aesthetics**: Beautiful dark mode, glassmorphism UI elements, and smooth micro-animations.
*   **In-game Notes**: Keep track of clues and answers directly in the app.

## 🛠️ Technology Stack

*   **Frontend**: Flutter (Dart)
*   **Backend**: Firebase Realtime Database
*   **State Management**: Provider
*   **Audio**: Audioplayers for immersive sound effects.
*   **Graphics**: Modern design system with responsive layouts for mobile and web.

## 📱 Getting Started

### Prerequisites
*   Flutter SDK (Latest version recommended)
*   A Firebase project setup with Realtime Database enabled.

### Installation
1.  **Clone the repository**:
    ```bash
    git clone https://github.com/Gigiux6/GuessMe.git
    ```
2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Firebase Configuration**:
    *   Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
    *   For Web, initialize Firebase in `index.html` or through `firebase_options.dart`.
4.  **Run the app**:
    ```bash
    flutter run
    ```

## 🌍 Localization
The app automatically detects your system language or allows you to change it in the settings.
*   🇮🇹 Italian
*   🇺🇸 English
*   🇪🇸 Spanish
*   🇩🇪 German
*   🇫🇷 French

## 🤝 Contributing
Contributions are welcome! Feel free to open issues or submit pull requests to improve the game.

## 📜 License
This project is licensed under the MIT License - see the LICENSE file for details.

---
*Created with ❤️ by Gigiux6*
