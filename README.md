# Multithreading Service Framework for Processing

## Overview

This project provides a foundational multithreading framework built with Processing (`.pde` files). It's designed to manage multiple services concurrently, making it suitable as a base for future applications, potentially including industrial supervision software. The framework features dynamic service loading, a message-based communication system, and a debug monitor.

## Features

*   **Multithreaded Service Execution:** Leverages multiple CPU cores by running services in separate threads, managed by a `ServiceScheduler`.
*   **Service-Based Architecture:** Promotes modularity by encapsulating functionalities within individual services (`BaseService`).
*   **Dynamic Service Loading:** Services can be enabled, disabled, and configured via an external `config.json` file without modifying the core code.
*   **Message Queue System:** Services communicate via asynchronous messages, with each service having its own input queue.
*   **Debug Monitor:** Provides a separate window to display real-time information about memory usage, thread activity, and service performance metrics.
*   **Configurable:** Service behavior like loop delay and preferred thread assignment can be set in `config.json`.

## Setup and Running

1.  **Prerequisites:**
    *   [Processing IDE](https://processing.org/download) (latest version recommended).
2.  **Clone the Repository:**
    ```bash
    # If you have git installed
    git clone https://github.com/SebastianCikes/DynamicMultithreadingProcessing
    ```
    Alternatively, download the source code as a ZIP file and extract it.
3.  **Open in Processing:**
    *   Open the Processing IDE.
    *   Go to `File > Open...` and navigate to the directory where you cloned/extracted the project.
    *   Select the `multithreading/multithreading.pde` file.
4.  **Run the Project:**
    *   Click the "Run" button (triangle icon) in the Processing IDE.

## Configuration (`multithreading/config.json`)

The `config.json` file located in the `multithreading` directory (i.e., `multithreading/config.json`) controls various settings:

*   `maxThreads`: Maximum number of threads the `ServiceScheduler` will use.
*   `debugMode`: Set to `true` to enable the `DebugWindow`, `false` to disable.
*   `services`: An object containing configurations for each service.
    *   `"ServiceName"`: The key should match the service class name.
        *   `enabled`: `true` or `false` to load or not load the service.
        *   `loopDelay`: Suggested execution interval for the service's `loop()` method in milliseconds.
        *   `thread`: Preferred thread index for the service (-1 for no preference, allowing the scheduler to assign).

Example `config.json` snippet:
```json
{
  "maxThreads": 4,
  "debugMode": true,
  "services": {
    "ParserService": {
      "enabled": true,
      "loopDelay": 50,
      "thread": 0
    },
    "LoggingService": {
      "enabled": true,
      "loopDelay": 10,
      "thread": -1
    },
    "TestService": {
      "enabled": false,
      "loopDelay": 1000,
      "thread": -1
    }
  }
}
```

## Creating New Services

For detailed instructions on how to create and integrate new services into this framework, please refer to the guide:
[How to Create a New Service](multithreading/HOW_TO_CREATE_A_SERVICE.md)

## Citation

If you use this software in your project, please consider citing it.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE.md) file for details.
