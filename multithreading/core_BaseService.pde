/**
 * Abstract base class for all services within the multithreading framework.
 * It defines the fundamental structure, lifecycle management, and communication mechanisms
 * for services. Services are designed to encapsulate specific tasks or functionalities and
 * are executed by a `ServiceThread`. The `ServiceThread` manages the invocation of the
 * service's `loop()` method, while the `run()` method (from the `Runnable` interface)
 * is primarily used for the initial one-time setup of the service.
 */
abstract class BaseService implements Runnable {
  // loopDelay: Specifies the suggested interval (in milliseconds) at which the service's
  // `loop()` method should be called. This is a request to the managing `ServiceThread`.
  // The actual execution frequency can also be affected by the `ServiceThread`'s own
  // polling interval (`threadLoopDelay`) and overall system load.
  int loopDelay = 10; // Default requested loop execution interval for this service.

  // inputQueue: Each service has its own message queue to receive messages from other
  // services or system components. It is of type `MessageQueue`.
  protected final MessageQueue inputQueue;

  // scheduler: A reference to the `ServiceScheduler` instance that manages this service.
  // This allows the service to interact with the scheduler, for example, to send
  // messages to other services.
  protected ServiceScheduler scheduler;

  // running: A volatile boolean flag that controls the main execution state of the service.
  // Setting this to `false` signals the service to stop its operations.
  // `volatile` ensures that changes to this flag are visible across threads.
  volatile boolean running = true;

  /**
   * Constructor for BaseService.
   * Initializes the service with a reference to the `ServiceScheduler` and a requested loop delay.
   *
   * @param scheduler The `ServiceScheduler` instance that will manage this service.
   *                  It's used for inter-service communication and lifecycle management.
   * @param loopDelay The desired delay in milliseconds between successive calls to the service's
   *                  `loop()` method. If a non-positive value is provided, a default of 10ms is used.
   */
  BaseService(ServiceScheduler scheduler, int loopDelay) {
    this.scheduler = scheduler;
    if (loopDelay <= 0) {
      // Ensure loopDelay is positive; otherwise, default to a sensible value.
      this.loopDelay = 10;
      println("Warning: Non-positive loopDelay (" + loopDelay + ") provided for service " + getClass().getSimpleName() + ". Defaulting to 10ms.");
    } else {
      this.loopDelay = loopDelay;
    }
    // Initialize the input queue with default capacity.
    // Consider making queue capacity configurable if needed in the future.
    this.inputQueue = new MessageQueue();
  }

  /**
   * Abstract method for one-time setup tasks.
   * This method is called once by the `ServiceThread` before the service's `loop()` method
   * is invoked for the first time. Subclasses must implement this to perform any necessary
   * initialization, such as loading resources, configuring hardware, or setting up internal state.
   */
  abstract void setup();

  /**
   * Abstract method for processing a single message from the input queue.
   * Subclasses must implement this method to define how the service reacts to
   * different types of messages it receives. This is where the core message-handling
   * logic of the service resides.
   *
   * @param message The `BaseMessage` instance dequeued from the input queue to be processed.
   */
  abstract void processMessage(BaseMessage message);

  /**
   * Core work logic of the service, called repeatedly by the `ServiceThread`.
   * This default implementation dequeues all available messages from the `inputQueue`
   * and passes them one by one to the `processMessage()` method.
   * It also checks the `running` flag before processing each message, ensuring that
   * the service stops processing new messages if `stop()` has been called.
   *
   * Services typically should not override this method unless they require a custom
   * message handling loop or need to perform actions even when no messages are present.
   */
  void loop() {
    BaseMessage message;
    // Process all messages currently in the queue in this tick.
    while ((message = inputQueue.dequeue()) != null) {
      if (!running) {
        // If the service has been stopped, log and break out of message processing.
        // Remaining messages in the queue might be lost or processed if the service is restarted.
        // For critical messages, consider a persistence or dead-letter queue mechanism if needed.
        println("Service " + getClass().getSimpleName() + " is stopping. " +
          (inputQueue.size() + 1) + " messages (including current) were in its queue. Further processing in this loop call is halted.");
        break;
      }
      // Delegate actual message handling to the abstract processMessage method.
      processMessage(message);
    }
  }

  /**
   * The main entry point when the service is started as a `Runnable` (e.g., by a Thread).
   * In this framework, `ServiceThread` manages the lifecycle. This `run()` method
   * is simplified to only call the `setup()` method for one-time initialization.
   * The continuous execution of `loop()` is handled by the managing `ServiceThread`.
   */
  @Override
    public void run() {
    // Perform one-time setup.
    setup();
    // Log that the setup phase, executed via this run() method, is complete.
    // The ServiceThread will take over calling loop() repeatedly.
    println(getClass().getSimpleName() + " run() method (setup phase) completed.");
  }

  /**
   * Signals the service to stop its execution.
   * This method sets the volatile `running` flag to `false`. The `loop()` method checks
   * this flag and will cease processing further messages. This is the primary mechanism
   * for gracefully requesting a service to stop.
   */
  public void stop() {
    println(getClass().getSimpleName() + " stop() called. Signaling service to terminate.");
    running = false;
  }

  /**
   * Checks if the service considers its work completed.
   * The base implementation defines "completed" as the `running` flag being `false`.
   * Services with specific finite tasks (e.g., processing a file, completing a calculation)
   * should override this method to provide a more accurate indication of their completion state.
   * For instance, a service might return `true` here once its primary task is finished,
   * even if `stop()` hasn't been explicitly called yet.
   *
   * @return `true` if the service has completed its work (default is `!running`), `false` otherwise.
   */
  public boolean isCompleted() {
    // Default: A service is considered completed if it's no longer in the 'running' state.
    // Override for services that have a natural completion point independent of being explicitly stopped.
    return !running;
  }

  /**
   * Performs cleanup of resources used by the service.
   * This method is intended to be called by the `ServiceScheduler` or `ServiceThread`
   * after a service has stopped or completed its work. Subclasses should override this
   * to release any external resources such as files, network connections, hardware interfaces, etc.
   * The base implementation simply logs that the method was called.
   */
  public void cleanup() {
    // Services should override this to release specific resources.
    // Examples: close file streams, shut down network listeners, free hardware locks.
    println(getClass().getSimpleName() + " base cleanup() called. Override if your service holds specific resources.");
  }

  /**
   * Gets the nominal priority of the service.
   * This is currently a placeholder and is **not** used by the `ServiceScheduler`
   * or `ServiceThread` for actual thread priority management in the OS.
   * It could be used in the future for custom scheduling logic if needed.
   *
   * @return The default priority value (5).
   */
  public int getPriority() {
    // This priority is not currently enforced at the OS thread level by ServiceThread.
    // It's available for potential future use in more advanced scheduling algorithms
    // within the ServiceScheduler itself.
    return 5; // Default nominal priority.
  }

  /**
   * Gets the suggested loop delay for this service in milliseconds.
   * This value is a request to the `ServiceThread` indicating how frequently
   * the service's `loop()` method should ideally be invoked.
   *
   * @return The configured loop delay in milliseconds.
   */
  public int getLoopDelay() {
    return this.loopDelay;
  }
}
