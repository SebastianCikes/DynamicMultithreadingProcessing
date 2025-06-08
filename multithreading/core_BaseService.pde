/**
 * Abstract base class for all services.
 * Defines the basic structure and lifecycle management for services.
 * Services are designed to be executed by a `ServiceThread` which manages the
 * invocation of the `loop()` method. The `run()` method of this class is
 * primarily for one-time setup.
 */
abstract class BaseService implements Runnable {
  // Defines the basic structure of a service class
  // This value is a request/suggestion to the managing ServiceThread regarding how often
  // this service's loop() method should ideally be called. The actual execution frequency
  // also depends on the ServiceThread's own polling interval ('threadLoopDelay').
  int loopDelay = 10; // Requested loop execution interval for this service (in milliseconds).
  protected final MessageQueue inputQueue; // Input queue for receiving messages
  protected ServiceScheduler scheduler; // Reference to the ServiceScheduler for inter-service communication

  volatile boolean running = true; // Flag to control the main run loop. Set to false to stop the service.

  /**
   * Constructor for BaseService.
   * @param scheduler The ServiceScheduler instance managing this service.
   * @param loopDelay The delay in milliseconds for the service's main loop.
   */
  BaseService(ServiceScheduler scheduler, int loopDelay) {
    this.scheduler = scheduler; // Store the scheduler instance
    if (loopDelay <= 0) {
      this.loopDelay = 10; // Default to 10ms if an invalid value is passed
    } else {
      this.loopDelay = loopDelay;
    }
    this.inputQueue = new MessageQueue();
  }

  /**
   * Abstract method for one-time setup tasks when the service starts.
   * This is called once before the main loop begins in the `run()` method.
   */
  abstract void setup();

  /**
   * Abstract method for processing a single message from the input queue.
   * @param message The BaseMessage to process.
   */
  abstract void processMessage(BaseMessage message);

  /**
   * Core work logic for the service. Dequeues and processes messages from the inputQueue.
   * This method is intended to be called repeatedly by an external execution manager (e.g., ServiceThread),
   * performing a segment of work (processing available messages) and then returning.
   */
  void loop() {
    BaseMessage message;
    // Process all messages currently in the queue before delaying.
    while ((message = inputQueue.dequeue()) != null) {
      if (!running) { // Check running state before each message processing.
        // If service was stopped, messages currently in the queue might be processed on a subsequent run
        // if the service is restarted, or they might be lost.
        // For now, just break the processing loop.
        println("Service " + getClass().getSimpleName() + " stopping: " + (inputQueue.size() +1) + " messages (incl. current) were in its queue.");
        break;
      }
      processMessage(message);
    }
  }

  /**
   * The main entry point when the service's thread is started.
   * For BaseService, this method is now primarily responsible for performing one-time setup tasks
   * by calling the `setup()` method. The continuous execution of the service's `loop()`
   * method is managed by an external class (e.g., `ServiceThread`).
   */
  public void run() {
    setup();
    // The run() method no longer contains the main execution loop.
    // ServiceThread (or a similar manager) will call loop() repeatedly.
    // Log that the setup phase, executed via run(), is complete.
    println(getClass().getSimpleName() + " run() method finished (setup complete).");
  }

  /**
   * Signals the service to stop its execution.
   * Sets the `running` flag to false, causing the `run()` loop to terminate.
   * This is the primary mechanism for gracefully stopping a service.
   */
  public void stop() {
    println(getClass().getSimpleName() + " stop() called. Setting running to false.");
    running = false;
  }

  /**
   * Checks if the service considers its work finished.
   * The base implementation returns true if the service's `running` flag is false.
   * Services with specific finite tasks or completion conditions should override this method
   * to provide a more accurate indication of their completion state. For example, a service
   * processing a file might return true once the entire file is processed, even if `stop()`
   * hasn't been called yet.
   * @return true if the service has completed its work, false otherwise.
   */
  public boolean isCompleted() {
    // Default implementation: service is completed if it's no longer running.
    // Services can override this for more specific completion logic (e.g., task finished).
    return !running;
  }

  /**
   * Performs cleanup of resources used by the service.
   * This method is intended to be called after a service has stopped or completed its work.
   * Services that manage external resources (e.g., network connections, files, hardware)
   * should override this method to release those resources.
   * The base implementation simply logs that cleanup is called.
   */
  public void cleanup() {
    // Services should override this method to perform specific cleanup tasks
    // such as closing files, releasing network sockets, etc.
    println(getClass().getSimpleName() + " base cleanup() called. Override if specific cleanup needed.");
  }

  /**
   * Gets the priority of the service. Currently, this is a placeholder
   * and not used by the ServiceScheduler for thread priority management.
   * @return The default priority value (5).
   */
  public int getPriority() {
    return 5; // default
  }

  /**
   * Gets the suggested loop delay for this service in milliseconds.
   * This value is used by ServiceThread to determine how often to call this service's loop() method.
   * @return The loop delay in milliseconds.
   */
  public int getLoopDelay() {
    return this.loopDelay;
  }
}
