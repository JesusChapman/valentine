<div align="center">
  <img src="preview/preview1.png" alt="Valentine App" width="700" style="border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.2);" />
  
  <h1>♥️ Valentine</h1>
  <p><strong>The best local music player for MacOS</strong></p>
  <p>The most elegant way to listen to your music files on your Mac, with a native and intuitive interface</p>

  [![macOS](https://img.shields.io/badge/macOS-Tahoe_26+-000000.svg?style=for-the-badge&logo=apple)](https://apple.com) [![Swift](https://img.shields.io/badge/Swift-5.9+-F05138.svg?style=for-the-badge&logo=swift)](https://swift.org) [![Homebrew](https://img.shields.io/badge/Homebrew-Install-F2A344.svg?style=for-the-badge&logo=homebrew)](#-installation) [![UI](https://img.shields.io/badge/UI-Liquid_Glass-ff69b4.svg?style=for-the-badge&logo=framer)](#) [![Open Source](https://img.shields.io/badge/Open_Source-%E2%9D%A4-10b981.svg?style=for-the-badge&logo=opensourceinitiative)](#)
  <br>
  [![GitHub Stars](https://img.shields.io/github/stars/jesuschapman/valentine.svg?style=for-the-badge&logo=github)](https://github.com/jesuschapman/valentine/stargazers) [![GitHub Issues](https://img.shields.io/github/issues/jesuschapman/valentine.svg?style=for-the-badge&logo=github)](https://github.com/jesuschapman/valentine/issues) [![Latest Release](https://img.shields.io/github/v/release/jesuschapman/valentine.svg?style=for-the-badge&logo=github)](https://github.com/jesuschapman/valentine/releases/latest) [![Liberapay](https://img.shields.io/badge/Donate-Liberapay-F6C915.svg?style=for-the-badge&logo=liberapay)](https://liberapay.com/jesuschapman)
</div>

<br/>

## 🌟 Overview
**Valentine** is a premium, beautifully crafted macOS application designed to play multiple files and audio formats on your Mac, all in an intuitive and modern player, with built-in lyrics support and a lyrics editor with search functions using lrclib.

<div align="center">

## Synchronized lyrics  

  <img src="preview/preview2.png" alt="Valentine App UI" width="700" style="border-radius: 12px; margin-top: 20px;" />


## Mini-Player

  <img src="preview/miniplayer_preview.png" alt="Valentine Mini Player UI" width="300" style="border-radius: 12px; margin-top: 20px;" />
</div>

---

## ✨ Key Features
- **Mutagen Powered ID3 Editing:** Valentine uses Python's `mutagen` under the hood to ensure robust, standard-compliant writing of metadata and lyrics directly into audio files (`.mp3`, `.flac`, `.m4a`, etc.).
- **Synchronized Lyrics Player:** Watch your lyrics highlight in real time, natively parsing LRC timestamps.
- **Dynamic Themes:** Adapts instantly to macOS Light and Dark mode. Features vivid neon glows, customizable typefaces, and a heavy use of Glassmorphism (blur backgrounds).
- **Native Media Controls:** Fully integrates with macOS media keys. Control your music right from your keyboard, Touch Bar, or your AirPods.
- **Drag & Drop:** Seamlessly drag your audio files and folders from Finder directly into the application window to populate your playlist.

---

## 🛠️ Built With (APIs & Libraries)
Valentine is made possible by these incredible open-source projects:

- **[LRCLib](https://lrclib.net/)**: The open-source lyrics API used to seamlessly search and fetch precise, time-synchronized `.lrc` lyrics.
- **[Mutagen](https://mutagen.readthedocs.io/)**: A highly robust Python multimedia tagging library used by our `MutagenInstallerService` to inject the lyrics securely into the ID3 metadata.
- **[AVFoundation](https://developer.apple.com/av-foundation/)**: Apple's native framework driving the `AudioEngine`, providing flawless audio playback and waveform data.

---

## 📦 Installation

The easiest way to install Valentine is using [Homebrew](https://brew.sh/). Simply run the following command in your terminal:

```bash
brew tap jesuschapman/valentine https://github.com/jesuschapman/valentine
brew install --cask jesuschapman/valentine/valentine
```

> **Note:** If macOS Gatekeeper blocks the app on its first launch, you can remove the quarantine flag by executing this command: `xattr -cr /Applications/Valentine.app`

---

## 🚀 How to Compile

To build Valentine from source, you need a Mac running **macOS Tahoe 26** or newer, and Xcode installed.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/jesuschapman/valentine.git
   cd valentine
   ```
2. **Open the Xcode Project:**
   ```bash
   open Valentine.xcodeproj
   ```
3. **Configure the Project:**
   - Go to the project settings and ensure you have selected your Apple Developer ID team.
   - Valentine uses Xcode 16's Synchronized Folders, so everything is ready to go out of the box.
4. **Build & Run:**
   - Select your Mac as the destination.
   - Press `Cmd + R` to compile and launch. 
   *(Note: The app will prompt you to install Mutagen via its UI dynamically if Python 3 is present on your system).*

---

## 💖 Sponsor this project
If you enjoy using Valentine or simply want to support its continued development, please consider buying me a coffee. Your support means the world and helps keep this app maintained and free!

<a href="https://liberapay.com/jesuschapman">
  <img src="https://liberapay.com/assets/widgets/donate.svg" alt="Donate using Liberapay" height="40">
</a>

---

## 📄 License
This project is licensed under the GNU General Public License. See the [LICENSE](LICENSE) file for more details.
