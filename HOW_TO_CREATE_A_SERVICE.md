# How to Create a New Service

## 1. Introduction

Services are the backbone of this multithreading framework. They encapsulate specific functionalities, running concurrently to process data, manage resources, or perform tasks. Each service operates independently but can communicate with others through a message-passing system. This modular approach allows for better organization, scalability, and maintainability of complex applications.

## 2. Core Concepts

Understanding these core components is essential for developing new services:

*   **`BaseService.pde`**: This is the abstract base class that all services must extend. It provides the fundamental structure and common functionalities for services.
    *   **Key Methods to Override:**
        *   `setup()`: Called once when the service is initialized. Use this for one-time setup tasks like loading configurations or initializing resources.
        *   `processMessage(BaseMessage message)`: This is where your service handles incoming messages. You'll implement the logic to react to different types of messages.
        *   `cleanup()`: Called when the service is being shut down. Use this to release any resources (files, network connections, etc.).
    *   **Key Methods to Optionally Override:**
        *   `isCompleted()`: Services can override this to indicate they have finished their work (e.g., after processing a specific file). By default, a service is considered "completed" when its `running` flag is set to `false` (usually via `stop()`).
    *   **Inherited Methods:**
        *   `loop()`: This method is called repeatedly by the `ServiceThread`. Its default implementation in `BaseService` dequeues messages from the service's input queue and passes them to `processMessage()`. You typically **do not** need to override `loop()` unless you require highly specialized control over the message dequeuing process.
        *   `stop()`: Signals the service to stop. Sets the internal `running` flag to `false`.
    *   **`loopDelay` Property (integer):** This protected field in `BaseService` (and configurable in `config.json`) suggests how often, in milliseconds, the `ServiceThread` should ideally attempt to execute the service's `loop()` method. The actual frequency can also be influenced by the `ServiceThread`'s own polling interval and system load.

*   **Service Lifecycle:**
    *   **Instantiation and Configuration:** Services are typically instantiated by the `ServiceScheduler` based on `config.json` or manually in `multithreading.pde`. Configuration parameters like `loopDelay` are passed during construction.
    *   **`setup()`:** Called once by the `ServiceThread` before the main loop begins. This is for one-time initialization tasks.
    *   **`loop()`:** Called repeatedly by the `ServiceThread`. The base implementation dequeues messages and calls `processMessage()`.
    *   **`processMessage(BaseMessage message)`:** Handles individual messages dequeued by `loop()`. This is where the core logic of the service resides.
    *   **`stop()`:** This method can be called (usually by the `ServiceScheduler` or `ServiceThread`) to signal the service that it should terminate. It sets an internal `running` flag to `false`.
    *   **`isCompleted()`:** Services can be queried via this method to see if they have finished their primary task. This is used by the `ServiceScheduler` to identify services that can be cleaned up.
    *   **`cleanup()`:** Called by the `ServiceThread` (usually when a service is removed) to allow the service to release any acquired resources.

*   **`ServiceScheduler.pde`**: This class is responsible for the overall management of services.
    *   It loads service configurations (often from `config.json`).
    *   It instantiates service objects.
    *   It assigns services to available `ServiceThread` instances for execution, attempting to balance the load or respect thread preferences.
    *   It starts the `ServiceThread`s.
    *   It periodically checks for services that have completed their work (via `isCompleted()`) and triggers their `cleanup()` process.
    *   It provides a mechanism for inter-service communication (`sendMessageToService`).

*   **`ServiceThread.pde`**: Each `ServiceThread` is an actual Java thread that executes the `loop()` method of one or more assigned services. It polls its assigned services based on their requested `loopDelay` and its own internal `threadLoopDelay`. It also handles metrics collection and can automatically stop services that cause too many consecutive errors.

*   **Message System (`BaseMessage.pde`, `MessageQueue.pde`):**
    *   Services are designed to be event-driven and communicate primarily through asynchronous messages.
    *   `BaseMessage.pde` is the abstract base class for all messages. Concrete message types (e.g., `RawDataMessage.pde`, `ParsedDataMessage.pde`) extend it to carry specific data.
    *   Each service instance has its own `MessageQueue` (an instance of `core_MessageQueue.pde`) to receive incoming messages. Messages are enqueued by other services or system components, and the `BaseService.loop()` method dequeues them for processing.

*   **Inter-Service Communication:**
    *   Services can send messages to other registered services using the `ServiceScheduler`.
    *   The method to use is `this.scheduler.sendMessageToService("TargetServiceNameString", new MyMessageObject());`.
    *   The `ServiceScheduler` looks up the target service by its string name and places the message in its input queue.

## 3. Steps to Create a New Service

Follow these steps to create and integrate a new service:

1.  **Create a new `.pde` file:**
    Name it descriptively, typically prefixed with `services_`, for example, `services_MyNewService.pde` within the `multithreading` directory.

2.  **Define the class:**
    The class must extend `BaseService`.

    ```pde
    class MyNewService extends BaseService {

      // Constructor: Must match one of the patterns expected by createServiceInstance in multithreading.pde
      // or be handled in createServiceManually.
      // Common constructor: (ServiceScheduler scheduler, int loopDelay)
      MyNewService(ServiceScheduler scheduler, int loopDelay) {
        super(scheduler, loopDelay); // Call the parent constructor
        // Any other initialization specific to MyNewService can go here
        println("MyNewService: Instantiated with loopDelay: " + loopDelay);
      }

      @Override
      void setup() {
        // This method is called once when the service is started by its ServiceThread.
        // Perform one-time initialization tasks here:
        // - Load configuration files specific to this service.
        // - Initialize hardware connections.
        // - Set up internal data structures.
        println("MyNewService: Setup complete and running on thread " + Thread.currentThread().getName());
      }

      @Override
      void processMessage(BaseMessage message) {
        // This method is called by the BaseService.loop() whenever a message
        // is available in this service's inputQueue.
        println("MyNewService received message of type: " + message.messageType + " on thread " + Thread.currentThread().getName());

        // Handle different types of messages
        if (message instanceof RawDataMessage) {
          RawDataMessage rawMsg = (RawDataMessage) message;
          println("MyNewService processing RawDataMessage. Payload: " + rawMsg.payload);
          // Process rawMsg.payload...
          // Example: Send a new message after processing
          // ParsedDataMessage psm = new ParsedDataMessage("Parsed from MyNewService: " + rawMsg.payload);
          // this.scheduler.sendMessageToService("LoggingService", psm);

        } else if (message instanceof ParsedDataMessage) {
          ParsedDataMessage parsedMsg = (ParsedDataMessage) message;
          println("MyNewService processing ParsedDataMessage. Content: " + parsedMsg.parsedContent);
          // Process ParsedDataMessage...

        } // Add more 'else if' blocks for other custom message types
          else {
          println("MyNewService received unhandled message type: " + message.messageType);
        }
      }

      // The loop() method is inherited from BaseService.
      // It handles dequeuing messages from inputQueue and calling processMessage().
      // You should ONLY override loop() if you need very specific custom behavior
      // for how messages are retrieved or if the service needs to perform actions
      // even when no messages are present. This is rare.
      // @Override
      // void loop() {
      //   super.loop(); // To maintain message processing
      //   // Custom logic for MyNewService's loop, if any
      // }

      @Override
      void cleanup() {
        // This method is called when the service is being stopped and removed.
        // Release any resources acquired during setup() or operation:
        // - Close files or database connections.
        // - Release hardware interfaces.
        // - Clear large data structures if necessary.
        println("MyNewService: Cleaning up resources on thread " + Thread.currentThread().getName());
      }

      // Optional: Override isCompleted() if your service has a defined end condition
      // other than just being stopped externally. For example, if it processes a
      // finite dataset and then is done.
      // @Override
      // boolean isCompleted() {
      //   // Example: return true if a specific task is finished
      //   // return myProcessingTaskIsFinished || super.isCompleted();
      //   return super.isCompleted(); // Default behavior relies on the 'running' flag
      // }
    }
    ```

3.  **Implement `setup()`**: Add any one-time initialization logic your service needs. This is called before the service's `loop()` begins.

4.  **Implement `processMessage()`**: This is the heart of your service. It will be called by the `BaseService`'s `loop()` method whenever a message arrives in the service's input queue. Use `instanceof` to check the type of `BaseMessage` and cast it appropriately to access its specific payload.

5.  **Implement `cleanup()`**: Add logic to release any resources (files, network connections, etc.) your service might have acquired. This is called when the service is stopped.

6.  **(Optional) Override `isCompleted()`**: If your service has a natural point at which its work is done (e.g., processing a file is complete), override `isCompleted()` to return `true` at that point. This allows the `ServiceScheduler` to clean it up. If not overridden, a service is typically considered "completed" only when `stop()` has been called and its `running` flag is false.

## 4. Configuring the New Service

For the `ServiceScheduler` to automatically load and manage your new service, you need to configure it:

1.  **Add to `config.json`**:
    Open the `config.json` file in the `data` directory of your sketch. Add an entry for your new service within the `services` object.

    ```json
    {
      "maxThreads": 4,
      "debugMode": true,
      "services": {
        "LoggingService": {
          "enabled": true,
          "loopDelay": 50,
          "thread": 0
        },
        "ParserService": {
          "enabled": true,
          "loopDelay": 100,
          "thread": 1
        },
        "TestService": {
          "enabled": false,
          "loopDelay": 1000,
          "thread": -1
        },
        "MyNewService": {
          "enabled": true,
          "loopDelay": 100,    // Desired loop delay in milliseconds for MyNewService
          "thread": -1         // Preferred thread: -1 for auto-assignment by scheduler,
                               // or a specific thread index (e.g., 0, 1, 2).
        }
      }
    }
    ```

    *   **`enabled` (boolean):** Set to `true` to have the scheduler load and run this service. `false` to disable it.
    *   **`loopDelay` (integer):** The desired interval in milliseconds at which the service's `loop()` method should be called. This is a suggestion to the `ServiceThread`.
    *   **`thread` (integer):** The index of the preferred `ServiceThread` to run this service on. `-1` means no preference, and the `ServiceScheduler` will assign it based on load balancing. If you specify a thread index (e.g., `0`, `1`), ensure it's within the range of `maxThreads`.

2.  **Manual Instantiation (Fallback Mechanism):**
    The `ServiceScheduler` attempts to load services using Java reflection. If your service has a constructor that doesn't match the common patterns checked by `createServiceInstance` in `multithreading.pde` (e.g., it has more complex or different parameter types), reflection might fail.
    In such cases, you need to add a manual instantiation case to the `createServiceManually()` method in `multithreading.pde`:

    ```pde
    // In multithreading.pde, inside createServiceManually()

    BaseService createServiceManually(String serviceName, DataBus bus, ServiceScheduler scheduler, int loopDelay) {
      switch (serviceName) {
        case "ParserService":
          return new ParserService(scheduler, loopDelay);
        case "TestService":
          return new TestService(bus, scheduler, loopDelay);
        case "LoggingService":
          return new LoggingService(scheduler, loopDelay);
        // Add your new service here:
        case "MyNewService":
          return new MyNewService(scheduler, loopDelay); // Ensure constructor matches
      default:
        println("ERROR: Unknown service: " + serviceName);
        return null;
      }
    }
    ```

3.  **Dummy Reference (Ensuring Compilation):**
    Processing sometimes doesn't compile inner classes (which `.pde` files effectively become) if they aren't explicitly referenced elsewhere in the main sketch file. To ensure your new service class is compiled and available for reflection or manual instantiation, add a "dummy reference" to it in the `setupDummyReferences()` method in `multithreading.pde`. This code is never actually executed because of the `if (false)` block, but it forces the compiler to include your service class.

    ```pde
    // In multithreading.pde, inside setupDummyReferences()

    void setupDummyReferences() {
      // These references force compilation without executing anything
      if (false) {
        new ParserService(null, 10);
        new TestService(null, null, 10);
        new LoggingService(null, 10);
        // Add dummy reference for your new service:
        new MyNewService(null, 10); // Pass null for scheduler and a default loopDelay
      }
    }
    ```

## 5. Best Practices

*   **Single Responsibility:** Design services to perform a specific, well-defined task or manage a particular piece of data. This makes them easier to understand, test, and maintain.
*   **Efficient Message Handling:** Make your `processMessage()` method as efficient as possible. Avoid long-blocking operations within this method, as it can prevent other messages in the queue from being processed and affect the responsiveness of the service. If you need to perform a long task, consider if it can be broken down or if the service needs to manage its own internal state across multiple `loop()` calls.
*   **Appropriate `loopDelay`:** Choose a `loopDelay` that makes sense for your service's task. A very short delay might consume unnecessary CPU if the service doesn't need to react that quickly. A very long delay might make the service unresponsive.
*   **Logging:** Use `println()` to log important events, errors, or state changes within your service. This is invaluable for debugging. The `LoggingService` can be used for more structured, centralized logging if needed.
*   **Resource Management:** Always ensure that any resources (files, network sockets, hardware interfaces, etc.) acquired by your service are properly released in the `cleanup()` method.
*   **Thread Safety:** While each service's `loop()` and `processMessage()` are called by a single `ServiceThread`, be mindful if your service shares data with other services or parts of the application directly (outside the message system). In such cases, ensure appropriate synchronization. The `DataBus` is a simple example of a synchronized shared data mechanism, but direct sharing should be minimized in favor of message passing.

By following these guidelines, you can create robust and efficient services that integrate well into the multithreading framework.
