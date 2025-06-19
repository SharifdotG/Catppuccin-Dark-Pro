# C/C++ Syntax Highlighting Improvements - v1.1.0

## 🎯 Enhanced Features

This version introduces comprehensive C/C++ language-specific syntax highlighting that goes beyond generic highlighting to provide specialized visual cues for C++ language constructs.

## 🔧 New Highlighting Rules

### Preprocessor Directives
- `#include`, `#define`, `#pragma` - **Orange with italic styling**
- Macro names - **Yellow with bold styling**
- Include file names - **Green**

### C++ Language Features
- **Namespace keywords** (`namespace`, `using`) - **Purple italic**
- **Namespace names** - **Yellow**
- **Scope resolution** (`::`) - **Teal**
- **Template keywords** (`template`, `typename`) - **Purple italic**
- **Template brackets** (`<>`) - **Purple**

### Object-Oriented Features
- **Class/struct keywords** - **Purple italic**
- **Class/struct names** - **Yellow bold**
- **Access specifiers** (`public`, `private`, `protected`) - **Red bold**
- **Function modifiers** (`virtual`, `override`, `final`) - **Purple italic**

### Modern C++ Features
- **Lambda expressions** - **Pink**
- **Lambda captures** (`[]`) - **Pink**
- **Lambda return type** (`->`) - **Teal**
- **Operator overloading** - **Blue italic**
- **C++ operators** (`new`, `delete`, `sizeof`, etc.) - **Teal bold**

### Language-Specific Elements
- **`this` keyword** - **Red italic**
- **Built-in types** (`int`, `double`, etc.) - **Teal**
- **Storage modifiers** (`inline`, `constexpr`) - **Purple italic**
- **Exception keywords** (`try`, `catch`, `throw`) - **Red bold**
- **Enum members** - **Teal**
- **Static assert** - **Yellow bold**

## 🎨 Color Mapping

| Element Type | Color | Style | Purpose |
|-------------|-------|-------|---------|
| Keywords | Purple (#cba6f7) | Italic | Language constructs |
| Types & Classes | Yellow (#f9e2af) | Bold | Type definitions |
| Functions | Blue (#89b4fa) | Normal/Italic | Function calls/definitions |
| Operators | Teal (#94e2d5) | Bold | Mathematical/logical ops |
| Literals | Green (#a6e3a1) | Normal | Strings, includes |
| Special | Red (#f38ba8) | Bold/Italic | Access, exceptions |
| Modifiers | Purple (#cba6f7) | Italic | Storage modifiers |

## 🚀 Technical Implementation

- Integrated with VS Code's official C++ TextMate grammar
- Added 20+ new syntax highlighting rules
- Maintained Catppuccin color palette consistency
- Used semantic color coding for enhanced readability
- Applied appropriate font styling (italic/bold) for visual hierarchy

## 📝 Examples

The enhanced highlighting improves readability for constructs like:

```cpp
// Preprocessor directives (orange italic)
#include <iostream>
#define MAX_SIZE 100

// Namespace and scope resolution (purple, yellow, teal)
namespace MyNamespace {
    using std::cout;
}

// Templates (purple italic, purple brackets)
template<typename T>
class Container { };

// Classes with access specifiers (yellow bold, red bold)
class Shape {
private:
    int size;
public:
    virtual void draw() = 0;  // virtual in purple italic
};

// Modern C++ features (pink, teal)
auto lambda = [capture](int x) -> int {
    return x * 2;
};

// Operators and built-ins (teal bold, teal)
int* ptr = new int(42);
sizeof(ptr);
```

This enhancement makes C/C++ code more readable and helps developers quickly identify different language constructs while maintaining the beautiful Catppuccin aesthetic.
