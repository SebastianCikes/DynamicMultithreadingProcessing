import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Collections;

/**
 * Acts as an executor for a collection of BaseService instances.
 * This thread runs its own loop which serves as a "tick" or polling cycle.
 * In each tick, it checks assigned services to see if they are due to run based on their
 * individual `loopDelay` requests.
 * It calls `setup()` once for each service, then repeatedly calls `loop()` on due services,
 * collecting performance and error metrics.
 */
class ServiceThread extends Thread {
  private volatile boolean running = true;
  private final ArrayList<BaseService> assignedServices = new ArrayList<BaseService>();

  // Defines the ServiceThread's own "tick" or polling interval in milliseconds.
  // This determines how frequently it checks if assigned services are due to run.
  // A smaller threadLoopDelay allows for more granular adherence to individual service loopDelays,
  // but increases polling overhead.
  private int threadLoopDelay = 50;

  // Map to store ServiceMetrics for each BaseService instance.
  private final Map<BaseService, ServiceMetrics> serviceMetricsMap = new HashMap<BaseService, ServiceMetrics>();

  // Map to store the nanosecond timestamp of when each service's loop() was last initiated.
  // This is crucial for the individualized pacing logic.
  private final Map<BaseService, Long> serviceLastExecutionNanos = new HashMap<BaseService, Long>();

  /**
   * Adds a service to this ServiceThread's execution list.
   * This method is assumed to be called before this ServiceThread itself is started.
   * It initializes {@link ServiceMetrics} for the service and sets its last execution time
   * to 0, ensuring it's eligible to run on the first possible tick.
   * @param s The BaseService instance to add.
   */
  public void addService(BaseService s) { // Made public for ServiceScheduler access
    if (s != null) {
      // Considerations for thread safety if services are added dynamically:
      // 1. Use `Collections.synchronizedList(assignedServices)` in constructor.
      // 2. Add to a temporary concurrent list and merge into assignedServices within the run loop.
      // For now, assuming addService is called before this thread's start().
      this.assignedServices.add(s);
      ServiceMetrics metrics = new ServiceMetrics(s.getClass().getSimpleName());
      this.serviceMetricsMap.put(s, metrics);
      this.serviceLastExecutionNanos.put(s, 0L); // Initialize to 0 to make it due on first check.
      println(getName() + ": Service " + s.getClass().getSimpleName() + " added, metrics and initial exec time set. Total services: " + assignedServices.size());
    }
  }

  /**
   * The main execution method for this ServiceThread.
   * This method performs the following steps:
   * 1. Calls `setup()` once for every assigned service before starting the main loop.
   *    If a service's setup fails, it's logged, and the service is marked as not running.
   * 2. Enters a `while(this.running)` loop. This loop represents the "tick" or polling cycle
   *    of the `ServiceThread`. The frequency of this tick is controlled by `this.threadLoopDelay`.
   * 3. Inside each tick:
   *    a. It takes a snapshot of the `assignedServices` list to allow for safe concurrent modification
   *       (e.g., by `removeService`).
   *    b. It records `currentTimeNanosForTick`, a consistent timestamp for all service checks within this tick.
   *    c. For each service in the snapshot:
   *        i. If the service is not `running` (its own flag), it's skipped.
   *       ii. It calculates if the service is "due" to run by comparing `currentTimeNanosForTick`
   *           with its `lastExecTimeNanos` (from `serviceLastExecutionNanos` map) and its
   *           requested `loopDelay` (from `service.getLoopDelay()`).
   *      iii. If the service is due:
   *           - Its `lastExecTimeNanos` is updated to `currentTimeNanosForTick` *before* calling `loop()`.
   *           - `service.loop()` is called.
   *           - Performance metrics (execution time) or error metrics are recorded for this execution of `loop()`.
   *             Exceptions during `service.loop()` are caught, logged, and error count is incremented.
   * 4. After checking all services in the current tick, `delay(this.threadLoopDelay)` is called, pausing the
   *    `ServiceThread` until its next polling cycle. The accuracy of service execution relative to their
   *    requested `loopDelay` is influenced by this `threadLoopDelay` (e.g., a service with a 10ms
   *    `loopDelay` cannot run more frequently than the `ServiceThread`'s `threadLoopDelay`).
   */
  @Override
    public void run() {
    println(getName() + ": Starting setup for " + assignedServices.size() + " services...");
    // 1. Call setup() for all assigned services ONCE.
    // Iterate over a copy in case a setup method tries to modify the list (unlikely but safe)
    for (BaseService service : new ArrayList<BaseService>(assignedServices)) {
      try {
        if (service.running) { // Only setup if it hasn't been stopped before starting
          println(getName() + ": Setting up " + service.getClass().getSimpleName());
          service.setup(); // BaseService.run() used to call this, now ServiceThread does.
          // The service's own run() method has been simplified to do nothing or minimal setup.
          println(getName() + ": " + service.getClass().getSimpleName() + " setup complete.");
        } else {
          println(getName() + ": " + service.getClass().getSimpleName() + " was already stopped before setup.");
        }
      }
      catch (Exception e) {
        println(getName() + ": Exception during setup for " + service.getClass().getSimpleName() + ": " + e.getMessage());
        e.printStackTrace(); // Good for debugging
        service.stop(); // Mark service as not running if its setup failed.
        // Optionally, remove it here or let ServiceScheduler handle it. For now, just stop.
      }
    }
    println(getName() + ": All service setups attempted. Starting main execution loop with delay " + threadLoopDelay + "ms.");

    // 2. Main execution loop
    while (this.running) {
      // Iterate over a copy of assignedServices for thread safety during removals.
      List<BaseService> servicesSnapshot = new ArrayList<>(this.assignedServices);
      long currentTimeNanosForTick = System.nanoTime(); // Consistent time for all checks in this tick.

      for (BaseService service : servicesSnapshot) {
        if (!service.running) {
          // println(getName() + ": Skipping " + service.getClass().getSimpleName() + " as it's not running."); // Verbose
          continue; // Skip if the service itself is not running
        }

        long lastExecTimeNanos = this.serviceLastExecutionNanos.getOrDefault(service, 0L);
        long requiredDelayNanos = (long)service.getLoopDelay() * 1_000_000L; // Convert service's ms delay to ns

        boolean isDue = (currentTimeNanosForTick - lastExecTimeNanos) >= requiredDelayNanos;

        if (isDue) {
          this.serviceLastExecutionNanos.put(service, currentTimeNanosForTick); // Update last execution time *before* calling loop

          ServiceMetrics metrics = this.serviceMetricsMap.get(service);
          long metricsStartTimeNanos = System.nanoTime(); // For precise metrics timing of loop()

          try {
            service.loop(); // Execute the service's main logic

            if (metrics != null) {
              long durationNanos = System.nanoTime() - metricsStartTimeNanos;
              metrics.recordLoopTime(durationNanos);
            }
          }
          catch (Exception e) {
            // Using System.err for errors to make them stand out, consistent with e.printStackTrace()
            System.err.println(getName() + ": ERROR in service " + service.getClass().getSimpleName() + " loop(): " + e.getMessage());
            e.printStackTrace(System.err);

            if (metrics != null) {
              metrics.incrementErrorCount();
            }
            // Optional: service.stop(); // if a single error should stop the service.
          }
        }
      }

      try {
        delay(this.threadLoopDelay); // This ServiceThread's own "tick" or polling interval.
      }
      catch (Exception e) {
        System.err.println(getName() + ": Delay interrupted: " + e.getMessage());
        if (!this.running) {
          println(getName() + ": Thread was stopped during delay, exiting loop.");
          break; // Exit if the thread was stopped.
        }
      }
    }
    println(getName() + ": Execution loop finished.");
  }

  /**
   * Signals a service to stop, performs cleanup, and removes it from this ServiceThread's management.
   * This includes removing it from the list of assigned services, its metrics tracking,
   * and its last execution time tracking.
   * @param service The BaseService instance to remove.
   */
  public void removeService(BaseService service) { // Made public for ServiceScheduler access
    if (this.assignedServices.contains(service)) {
      String serviceName = service.getClass().getSimpleName();
      println(getName() + ": Removing service " + serviceName);

      try {
        println(getName() + ": Attempting to stop service " + serviceName);
        service.stop(); // Signal the service to stop its own operations.
        println(getName() + ": Service " + serviceName + " stop method called.");
      }
      catch (Exception e) {
        println(getName() + ": Exception during service.stop() for " + serviceName + ": " + e.getMessage());
      }

      try {
        println(getName() + ": Attempting to cleanup service " + serviceName);
        service.cleanup(); // Allow the service to release its resources.
        println(getName() + ": Service " + serviceName + " cleanup method called.");
      }
      catch (Exception e) {
        println(getName() + ": Exception during service.cleanup() for " + serviceName + ": " + e.getMessage());
      }

      // The run() loop iterates a snapshot of assignedServices, so direct removal here is
      // generally safe for the list itself. Concurrent access to maps is also handled by HashMap's
      // non-synchronized nature (external synchronization would be needed if adds/removals happened
      // from multiple threads without control, but here removeService is called by ServiceScheduler,
      // typically after ServiceThread might be stopped or in a controlled state).
      boolean removedFromList = this.assignedServices.remove(service);
      if (removedFromList) {
        this.serviceMetricsMap.remove(service);          // Remove its metrics.
        this.serviceLastExecutionNanos.remove(service);  // Remove its last execution time record.
        println(getName() + ": Service " + serviceName + " fully removed. Remaining: " + assignedServices.size());
      }
    } else {
      println(getName() + ": Service " + service.getClass().getSimpleName() + " not found for removal.");
    }
  }

  /**
   * Returns the list of services currently assigned to this ServiceThread.
   * The returned collection is a copy and cannot be used to modify the internal list.
   * @return A collection of BaseService instances.
   */
  public Collection<BaseService> getAssignedServices() {
    // Return a copy to prevent external modification of the internal list.
    return new ArrayList<BaseService>(this.assignedServices);
  }

  /**
   * Returns an unmodifiable view of the map storing ServiceMetrics for each service.
   * This allows external classes to inspect metrics without being able to modify the map.
   * @return An unmodifiable Map of BaseService instances to their ServiceMetrics.
   */
  public Map<BaseService, ServiceMetrics> getServiceMetricsMap() {
    // Return a new HashMap copy wrapped in an unmodifiableMap for safety.
    // This prevents external modification of the internal map and its contents via the returned reference.
    return Collections.unmodifiableMap(new HashMap<>(this.serviceMetricsMap));
  }

  /**
   * Signals this ServiceThread to stop its main execution loop.
   * The loop will terminate after the current iteration completes.
   */
  public void stopThread() {
    println(getName() + ": stopThread() called. Setting running to false.");
    this.running = false;
    // If the thread is in delay(), it might be useful to interrupt it.
    // However, BaseService.delay() is a Processing function and its interruptibility needs care.
    // Standard Thread.sleep() is interruptible. For now, just setting flag.
    // this.interrupt(); // Consider if BaseService.delay() handles InterruptedException
  }

  /**
   * Gets the configured loop delay for this ServiceThread.
   * @return The delay in milliseconds.
   */
  public int getThreadLoopDelay() {
    return threadLoopDelay;
  }

  /**
   * Sets the loop delay for this ServiceThread.
   * @param delayMs The delay in milliseconds.
   */
  public void setThreadLoopDelay(int delayMs) {
    if (delayMs > 0) {
      this.threadLoopDelay = delayMs;
      println(getName() + ": Thread loop delay set to " + delayMs + "ms.");
    } else {
      println(getName() + ": Invalid thread loop delay: " + delayMs + "ms. Keeping current: " + this.threadLoopDelay + "ms.");
    }
  }
}
