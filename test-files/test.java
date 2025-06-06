import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.io.IOException;
import static java.lang.System.out;

package com.example.theme.test;

/**
 * Sample Java class for testing syntax highlighting
 *
 * @author Theme Tester
 * @version 1.0
 */
public class test extends BaseClass implements Runnable, Comparable<String> {

    // Class constants
    private static final String CONSTANT_STRING = "Hello, World!";
    private static final int MAX_SIZE = 100;
    public static final double PI = 3.14159;

    // Instance variables
    private String name;
    private int[] numbers;
    private List<String> items;
    private Map<String, Object> properties;
    protected boolean isActive = true;

    // Enum for testing
    public enum Status {
        ACTIVE("Active"),
        INACTIVE("Inactive"),
        PENDING("Pending");

        private final String displayName;

        Status(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() {
            return displayName;
        }
    }

    // Inner class
    private static class InnerHelper {
        private String data;

        public InnerHelper(String data) {
            this.data = data;
        }
    }

    // Constructor
    public SyntaxHighlightTest(String name) {
        this.name = name;
        this.numbers = new int[] { 1, 2, 3, 4, 5 };
        this.items = new ArrayList<>();
        this.properties = new HashMap<>();

        // Initialize collections
        Collections.addAll(items, "red", "green", "blue");
        properties.put("version", 1.0);
        properties.put("debug", true);
    }

    // Method with annotations
    @Override
    @SuppressWarnings("unchecked")
    public void run() {
        System.out.println("Running thread: " + Thread.currentThread().getName());

        // String operations
        String message = String.format("Processing %s with %d items", name, items.size());
        String multiLine = """
                This is a text block
                spanning multiple lines
                with proper indentation
                """;

        out.println(message);
        out.println(multiLine);
    }

    // Generic method
    public <T extends Comparable<T>> T findMax(T[] array) {
        if (array == null || array.length == 0) {
            return null;
        }

        T max = array[0];
        for (T item : array) {
            if (item.compareTo(max) > 0) {
                max = item;
            }
        }
        return max;
    }

    // Method with various control structures
    public void demonstrateControlFlow() {
        // If-else statements
        if (isActive) {
            System.out.println("System is active");
        } else if (name != null && !name.isEmpty()) {
            System.out.println("Name is set: " + name);
        } else {
            System.out.println("System is inactive");
        }

        // Switch expression (Java 14+)
        Status currentStatus = Status.ACTIVE;
        String statusMessage = switch (currentStatus) {
            case ACTIVE -> "System is running";
            case INACTIVE -> "System is stopped";
            case PENDING -> "System is starting";
        };

        // Traditional switch
        switch (numbers.length) {
            case 0:
                System.out.println("Empty array");
                break;
            case 1:
                System.out.println("Single element");
                break;
            default:
                System.out.println("Multiple elements: " + numbers.length);
        }

        // Loops
        for (int i = 0; i < numbers.length; i++) {
            System.out.printf("numbers[%d] = %d%n", i, numbers[i]);
        }

        // Enhanced for loop
        for (String item : items) {
            if ("red".equals(item)) {
                continue;
            }
            System.out.println("Item: " + item);
        }

        // While loop
        int counter = 0;
        while (counter < 5) {
            System.out.println("Counter: " + counter++);
        }

        // Do-while loop
        do {
            counter--;
        } while (counter > 0);
    }

    // Exception handling
    public void demonstrateExceptions() throws IOException {
        try {
            riskyOperation();
        } catch (IllegalArgumentException e) {
            System.err.println("Invalid argument: " + e.getMessage());
        } catch (RuntimeException e) {
            System.err.println("Runtime error: " + e.getClass().getSimpleName());
            throw e;
        } finally {
            System.out.println("Cleanup completed");
        }

        // Try-with-resources
        try (Scanner scanner = new Scanner(System.in)) {
            String input = scanner.nextLine();
            System.out.println("Input received: " + input);
        }
    }

    private void riskyOperation() {
        if (Math.random() > 0.5) {
            throw new IllegalArgumentException("Random failure");
        }
    }

    // Lambda expressions and streams
    public void demonstrateLambdas() {
        // Lambda expressions
        Runnable task = () -> System.out.println("Lambda task executed");
        task.run();

        // Method references
        items.forEach(System.out::println);

        // Stream operations
        List<String> processedItems = items.stream()
                .filter(item -> item.length() > 3)
                .map(String::toUpperCase)
                .sorted()
                .collect(Collectors.toList());

        // Complex stream with multiple operations
        Optional<String> longestItem = items.stream()
                .filter(item -> !item.isEmpty())
                .max(Comparator.comparing(String::length));

        longestItem.ifPresent(item -> System.out.println("Longest item: " + item));

        // Parallel stream
        numbers = Arrays.stream(numbers)
                .parallel()
                .map(n -> n * 2)
                .filter(n -> n > 5)
                .toArray();
    }

    // Async programming
    public CompletableFuture<String> asyncOperation() {
        return CompletableFuture
                .supplyAsync(() -> {
                    // Simulate long-running operation
                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                    return "Async result for " + name;
                })
                .thenApply(String::toUpperCase)
                .exceptionally(throwable -> {
                    System.err.println("Async operation failed: " + throwable.getMessage());
                    return "Default result";
                });
    }

    // Interface implementation
    @Override
    public int compareTo(String other) {
        return this.name.compareTo(other);
    }

    // Getters and setters
    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public boolean isActive() {
        return isActive;
    }

    public void setActive(boolean active) {
        isActive = active;
    }

    // Main method for testing
    public static void main(String[] args) {
        System.out.println("=== Java Syntax Highlighting Test ===");

        SyntaxHighlightTest test = new SyntaxHighlightTest("TestInstance");

        // Test various features
        test.demonstrateControlFlow();
        test.demonstrateLambdas();

        try {
            test.demonstrateExceptions();
        } catch (IOException e) {
            e.printStackTrace();
        }

        // Test async operation
        CompletableFuture<String> future = test.asyncOperation();
        future.thenAccept(result -> System.out.println("Async result: " + result));

        // Regular expressions
        String pattern = "\\d{3}-\\d{2}-\\d{4}";
        String testString = "123-45-6789";
        boolean matches = testString.matches(pattern);
        System.out.println("Pattern matches: " + matches);

        // Numeric literals
        int binary = 0b1010;
        int hex = 0xFF;
        int octal = 077;
        long longValue = 123_456_789L;
        float floatValue = 3.14f;
        double doubleValue = 2.718281828;

        System.out.printf("Binary: %d, Hex: %d, Octal: %d%n", binary, hex, octal);
        System.out.printf("Long: %d, Float: %.2f, Double: %.9f%n",
                longValue, floatValue, doubleValue);
    }
}

// Abstract base class
abstract class BaseClass {
    protected abstract void abstractMethod();

    public void concreteMethod() {
        System.out.println("Concrete implementation");
    }
}

// Interface for testing
interface TestInterface {
    String INTERFACE_CONSTANT = "Interface Constant";

    void interfaceMethod();

    default void defaultMethod() {
        System.out.println("Default interface method");
    }

    static void staticMethod() {
        System.out.println("Static interface method");
    }
}

// Record class (Java 14+)
record Person(String name, int age, String email) {
    // Compact constructor
    public Person{if(age<0){throw new IllegalArgumentException("Age cannot be negative");}}

    // Custom method
    public boolean isAdult() {
        return age >= 18;
    }
}

// Sealed class (Java 17+)
sealed class Shape permits Circle, Rectangle, Triangle {
    protected final String color;

    protected Shape(String color) {
        this.color = color;
    }
}

final class Circle extends Shape {
    private final double radius;

    public Circle(String color, double radius) {
        super(color);
        this.radius = radius;
    }
}

final class Rectangle extends Shape {
    private final double width, height;

    public Rectangle(String color, double width, double height) {
        super(color);
        this.width = width;
        this.height = height;
    }
}

non-sealed class Triangle extends Shape {
    public Triangle(String color) {
        super(color);
    }
}