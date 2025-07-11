# Changelog

All notable changes to the "Catppuccin Dark Pro" extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-06-20

### Added

- 🎯 **Enhanced C/C++ Syntax Highlighting**: Added comprehensive language-specific syntax highlighting for C and C++
- 🔧 **Preprocessor Directives**: Specialized highlighting for `#include`, `#define`, `#pragma`, and other preprocessor directives with italic styling
- 🏗️ **C++ Language Features**: Enhanced support for:
  - Namespace keywords and names with distinct colors
  - Scope resolution operators (`::`) in teal
  - Template keywords and angle brackets
  - Class/struct/union declarations with bold names
  - Access specifiers (`public`, `private`, `protected`) in bold red
  - Function modifiers (`virtual`, `override`, `final`) with italic styling
  - Lambda expressions with pink capture brackets
  - Operator overloading with italic blue styling
  - Built-in primitive types in teal
  - Exception handling keywords in bold red
- 🎨 **Language-Specific Italics**: Added italic styling for appropriate C++ keywords and modifiers
- 📋 **TextMate Grammar Integration**: Leveraged official C++ TextMate grammar scopes for precise highlighting
- 🎯 **Enhanced Readability**: Improved visual distinction between different C++ language constructs

### Changed

- 📝 Updated package description to mention enhanced C/C++ highlighting
- 🔄 Version bump from 1.0.2 to 1.1.0 for minor feature update

### Technical Details

- Added 20+ new syntax highlighting rules specifically for C/C++ language constructs
- Integrated with VS Code's official C++ TextMate grammar scopes
- Maintained Catppuccin color palette consistency while adding language-specific enhancements
- Used semantic colors: Purple for keywords, Blue for functions, Yellow for types, Teal for operators, etc.

## [1.0.2] - 2025-06-06

### Changed

- 👤 Updated publisher from `catppuccin-dark-pro` to `SharifdotG` in package.json
- 🔗 Updated repository URLs to point to `https://github.com/SharifdotG/Catppuccin-Dark-Pro`
- 📝 Updated all GitHub references and links in README.md to reflect new repository location
- 🎨 Updated version badges and marketplace links in README.md to show v1.0.2
- 👨‍💻 Updated author information to "Sharif Md. Yousuf"
- 📸 Updated SCREENSHOT.png with improved theme preview

### Added

- 📦 Generated new VSIX package file (catppuccin-dark-pro-1.0.2.vsix) with updated metadata

### Fixed

- 🔗 Fixed all broken repository links and references
- 📚 Ensured consistency between package.json and README.md metadata
- 🏷️ Updated version references throughout documentation

### Known Issues

- ⚠️ Some repository URLs in README.md still reference old repository location and need to be updated

## [1.0.1] - 2025-06-06

### Changed

- 🎨 Updated extension icon from `icon.png` to `LOGO.png` in package.json
- 📝 Enhanced README.md with comprehensive visual improvements:
  - Added centered logo display at the top
  - Integrated local SCREENSHOT.png for theme preview
  - Improved layout with better HTML structure and centering
  - Added detailed installation instructions and customization options
- 🔧 Updated package.json version to 1.0.1
- 📚 Expanded documentation with advanced features and technical details

### Added

- 🖼️ Local logo and screenshot integration in README
- 📖 Comprehensive feature comparison table
- ⚙️ Detailed customization guide with recommended VS Code settings
- 🧠 Advanced semantic highlighting documentation
- 🎨 Color philosophy and science section
- 🚀 Multiple installation methods (Marketplace and Manual)
- 🤝 Contributing guidelines and development setup instructions

### Fixed

- 📁 File structure alignment between package.json and actual project files
- 🔗 Image references now use local files instead of remote URLs

## [1.0.0] - 2025-06-06

### Added

- Initial release of Catppuccin Dark Pro theme
- 🎨 Ultra-flat UI design combining Catppuccin Mocha colors with One Dark Pro syntax highlighting
- 🌙 Harmonized color palette for reduced eye strain
- ⚡ Enhanced syntax highlighting for multiple languages:
  - JavaScript/TypeScript and React/JSX/TSX
  - Python with decorator and f-string support
  - HTML/CSS/SCSS with intelligent property distinction
  - JSON with clean key-value visualization
  - Markdown with elegant documentation styling
- 🔧 Complete semantic token color definitions
- 📱 Seamless flat design with minimal borders and subtle contrasts
- 🎯 Optimized transparency levels and focus indicators
- 🌈 Full ANSI terminal color scheme support

### Features

- Comprehensive language support with specialized token rules
- Modern flat interface design philosophy
- Soft, pastel colors for extended coding sessions
- Professional color harmony throughout VS Code interface
- Consistent design across all UI elements
