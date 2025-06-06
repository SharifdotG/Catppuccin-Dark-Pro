/*
 * Multi-line comment block
 * Testing syntax highlighting for C++ code
 * Author: Theme Tester
 * Date: 2024
 */

// Single line comment

#include <algorithm>
#include <iostream>
#include <map>
#include <memory>
#include <string>
#include <vector>

// Preprocessor directives
#define MAX_SIZE 100
#define DEBUG_MODE
#ifdef DEBUG_MODE
#define LOG(x) std::cout << x << std::endl
#else
#define LOG(x)
#endif

// Namespace declaration
namespace theme_test {

// Enum class
enum class Color {
    RED = 0xFF0000,
    GREEN = 0x00FF00,
    BLUE = 0x0000FF,
    PURPLE = 0x800080
};

// Structure definition
struct Point {
    double x, y;
    Point(double x = 0.0, double y = 0.0) : x(x), y(y) {}
};

// Class definition with inheritance
class Shape {
  protected:
    std::string name;
    Color color;

  public:
    // Constructor
    Shape(const std::string &name, Color color) : name(name), color(color) {}

    // Virtual destructor
    virtual ~Shape() = default;

    // Pure virtual function
    virtual double area() const = 0;

    // Virtual function
    virtual void display() const {
        std::cout << "Shape: " << name << std::endl;
    }

    // Static member function
    static int getShapeCount() {
        static int count = 0;
        return ++count;
    }

    // Const member function
    const std::string &getName() const noexcept { return name; }
};

// Derived class
class Rectangle : public Shape {
  private:
    double width, height;

  public:
    Rectangle(double w, double h, Color c = Color::BLUE)
        : Shape("Rectangle", c), width(w), height(h) {
        LOG("Rectangle created");
    }

    // Override virtual function
    double area() const override { return width * height; }

    void display() const override {
        Shape::display();
        std::cout << "Dimensions: " << width << "x" << height << std::endl;
    }

    // Operator overloading
    Rectangle operator+(const Rectangle &other) const {
        return Rectangle(width + other.width, height + other.height, color);
    }

    // Friend function declaration
    friend std::ostream &operator<<(std::ostream &os, const Rectangle &rect);
};

// Friend function definition
std::ostream &operator<<(std::ostream &os, const Rectangle &rect) {
    os << rect.name << ": " << rect.width << "x" << rect.height;
    return os;
}

// Template class
template <typename T> class Container {
  private:
    std::vector<T> data;

  public:
    void add(const T &item) { data.push_back(item); }
    void add(T &&item) { data.push_back(std::move(item)); }

    template <typename U> void addConverted(const U &item) {
        data.push_back(static_cast<T>(item));
    }

    size_t size() const { return data.size(); }

    // Iterator support
    auto begin() -> decltype(data.begin()) { return data.begin(); }
    auto end() -> decltype(data.end()) { return data.end(); }
    auto begin() const -> decltype(data.cbegin()) { return data.cbegin(); }
    auto end() const -> decltype(data.cend()) { return data.cend(); }
};

// Template function
template <typename T, typename U>
constexpr auto multiply(T a, U b) -> decltype(a * b) {
    return a * b;
}

// Template specialization
template <> class Container<std::string> {
  private:
    std::vector<std::string> data;

  public:
    void add(const std::string &str) { data.push_back(str); }

    void addUppercase(const std::string &str) {
        std::string upper = str;
        std::transform(upper.begin(), upper.end(), upper.begin(), ::toupper);
        data.push_back(upper);
    }
};

} // namespace theme_test

// Function with various parameter types
void demonstrateFeatures() {
    using namespace theme_test;

    // Variable declarations with different types
    int integer = 42;
    float pi = 3.14159f;
    double precision = 2.718281828;
    char character = 'A';
    bool flag = true;
    auto automatic = 100L;
    const char *cstring = "Hello, World!";
    std::string stdstring = "C++ Syntax Highlighting";

    // String literals
    std::string raw_string = R"(This is a raw string literal
    with multiple lines and "quotes")";

    // Numeric literals
    int decimal = 255;
    int hex = 0xFF;
    int octal = 0377;
    int binary = 0b11111111;

    // Pointers and references
    int *ptr = &integer;
    int &ref = integer;
    std::unique_ptr<Rectangle> smart_ptr =
        std::make_unique<Rectangle>(10.0, 20.0);

    // Arrays
    int array[5] = {1, 2, 3, 4, 5};
    std::vector<int> vector_data{10, 20, 30, 40, 50};

    // Control structures
    if (flag && integer > 0) {
        std::cout << "Condition is true" << std::endl;
    } else if (integer == 0) {
        std::cout << "Integer is zero" << std::endl;
    } else {
        std::cout << "Condition is false" << std::endl;
    }

    // Switch statement
    switch (integer) {
    case 42:
        std::cout << "The answer!" << std::endl;
        break;
    case 0:
        std::cout << "Zero" << std::endl;
        break;
    default:
        std::cout << "Other value: " << integer << std::endl;
        break;
    }

    // Loops
    for (int i = 0; i < 5; ++i) {
        std::cout << "Loop iteration: " << i << std::endl;
    }

    // Range-based for loop
    for (const auto &value : vector_data) {
        std::cout << "Vector element: " << value << std::endl;
    }

    // While loop
    int counter = 0;
    while (counter < 3) {
        std::cout << "Counter: " << counter++ << std::endl;
    }

    // Do-while loop
    do {
        std::cout << "Do-while iteration" << std::endl;
        --counter;
    } while (counter > 0);

    // Exception handling
    try {
        if (integer == 0) {
            throw std::runtime_error("Division by zero!");
        }
        double result = 100.0 / integer;
        std::cout << "Result: " << result << std::endl;
    } catch (const std::exception &e) {
        std::cerr << "Exception: " << e.what() << std::endl;
    } catch (...) {
        std::cerr << "Unknown exception!" << std::endl;
    }

    // Lambda expressions
    auto lambda = [&](int x, int y) -> int { return x + y + integer; };

    auto generic_lambda = [](auto a, auto b) { return a * b; };

    int sum = lambda(5, 10);
    auto product = generic_lambda(3.14, 2);

    // STL algorithms
    std::vector<int> numbers{5, 2, 8, 1, 9, 3};
    std::sort(numbers.begin(), numbers.end());

    auto found = std::find_if(numbers.begin(), numbers.end(),
                              [](int n) { return n > 5; });

    if (found != numbers.end()) {
        std::cout << "Found number greater than 5: " << *found << std::endl;
    }
}

// Main function
int main() {
    std::cout << "Testing C++ Syntax Highlighting" << std::endl;
    std::cout << "================================" << std::endl;

    // Function call
    demonstrateFeatures();

    // Object creation and method calls
    theme_test::Rectangle rect1(5.0, 3.0, theme_test::Color::RED);
    theme_test::Rectangle rect2(2.0, 4.0);

    rect1.display();
    std::cout << "Area: " << rect1.area() << std::endl;

    // Operator overloading usage
    auto rect3 = rect1 + rect2;
    std::cout << rect3 << std::endl;

    // Template usage
    theme_test::Container<int> int_container;
    int_container.add(1);
    int_container.add(2);
    int_container.add(3);

    theme_test::Container<std::string> string_container;
    string_container.add("Hello");
    string_container.addUppercase("world");

    // Template function usage
    auto result = theme_test::multiply(3.14, 2);
    std::cout << "Multiplication result: " << result << std::endl;

    return 0;
}

/* TODO: Add more advanced features
 * - Concepts (C++20)
 * - Modules (C++20)
 * - Coroutines (C++20)
 * - More template metaprogramming
 */

// Inline assembly (platform-specific)
#ifdef _MSC_VER
void inline_asm_example() {
    __asm {
        mov eax, 1
        mov ebx, 2
        add eax, ebx
    }
}
#endif