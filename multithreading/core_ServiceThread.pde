import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Collections;

/**
 * A `ServiceThread` is a dedicated thread responsible for executing a collection of `BaseService` instances.
 * It operates on a "tick" or polling cycle, defined by `threadLoopDelay`. In each cycle, it checks
 * its assigned services to determine if they are due for execution based on their individual `loopDelay`
 * settings.
 *
 * Key Responsibilities:
 * - Managing the lifecycle of assigned services: calling `setup()` once, then `loop()` repeatedly.
 * - Pacing the execution of each service according to its requested `loopDelay`.
 * - Collecting performance metrics (execution time) and error metrics for each service's `loop()` invocation.
 * - Implementing a resilience feature: automatically stopping a service if it encounters a configurable
 *   number of consecutive errors (`maxConsecutiveErrorsThreshold`) during its `loop()` execution.
 * - Providing methods to add, remove, and inspect assigned services and their metrics.
 */
class ServiceThread extends Thread {
  // running: A volatile boolean flag controlling the main execution loop of this ServiceThread.
  // Setting this to `false` (via `stopThread()`) will cause the thread to terminate its loop
  // after the current tick completes.
  private volatile boolean running = true;

  // assignedServices: A list holding all `BaseService` instances assigned to this ServiceThread.
  // Modifications to this list (add/remove) should be carefully managed, especially if done
  // while the thread is running. The current implementation iterates over a snapshot of this list
  // within its main loop to allow for safer concurrent removals.
  private final ArrayList<BaseService> assignedServices = new ArrayList<BaseService>();

  // threadLoopDelay: Defines this ServiceThread's own "tick" or polling interval in milliseconds.
  // This value determines how frequently the ServiceThread wakes up to check if any of its
  // assigned services are due to run. A smaller `threadLoopDelay` allows for more precise
  // adherence to individual service `loopDelay`s but increases the polling overhead of this thread.
  // Default is 50ms.
  private int threadLoopDelay = 50;

  /**
   * maxConsecutiveErrorsThreshold: Defines the threshold for automatically stopping a service
   * if its `loop()` method throws an exception for this many consecutive execution attempts.
   * If a service's `loop()` fails this many times in a row, this ServiceThread will call
   * `service.stop()` to prevent a potentially misbehaving service from consuming resources
   * or spamming logs indefinitely.
   * Default is 3. Can be configured via {@link #setMaxConsecutiveErrorsThreshold(int)}.
   */
  private int maxConsecutiveErrorsThreshold = 3;

  // serviceMetricsMap: A map to store `ServiceMetrics` objects for each `BaseService` instance
  // managed by this thread. Metrics include loop execution counts, times, and error counts.
  private final Map<BaseService, ServiceMetrics> serviceMetricsMap = new HashMap<BaseService, ServiceMetrics>();

  // serviceLastExecutionNanos: A map storing the nanosecond timestamp (from `System.nanoTime()`)
  // of when each service's `loop()` method was last *initiated*. This is crucial for the
  // individualized pacing logic, determining when a service is next due to run based on its `loopDelay`.
  private final Map<BaseService, Long> serviceLastExecutionNanos = new HashMap<BaseService, Long>();

  /**
   * Adds a `BaseService` instance to this ServiceThread's execution list.
   * This method is typically called by the `ServiceScheduler` before this `ServiceThread` is started.
   * It initializes a {@link ServiceMetrics} object for the service and sets its last execution time
   * to 0, ensuring it's eligible to run on the first possible tick after the thread starts.
   *
   * @param s The `BaseService` instance to add. If null, the method does nothing.
   */
  public void addService(BaseService s) { // Made public for ServiceScheduler access
    if (s != null) {
      // Thread safety considerations if services are added *after* this thread has started:
      // The current `run()` loop iterates over a snapshot of `assignedServices`.
      // Direct addition here while `run()` is iterating the snapshot is generally safe for the snapshot.
      // However, for true dynamic addition to a live thread, a concurrent collection or
      // proper synchronization for `assignedServices`, `serviceMetricsMap`, and
      // `serviceLastExecutionNanos` would be more robust.
      // For now, the design assumes services are primarily added before `Thread.start()`.
      this.assignedServices.add(s);
      ServiceMetrics metrics = new ServiceMetrics(s.getClass().getSimpleName());
      this.serviceMetricsMap.put(s, metrics);
      // Initialize last execution time to 0. This ensures the service is considered "due"
      // for its first execution attempt as soon as the thread's main loop begins.
      this.serviceLastExecutionNanos.put(s, 0L);
      println(getName() + ": Service " + s.getClass().getSimpleName() +
        " added. Metrics initialized. Total services now: " + assignedServices.size());
    } else {
      println(getName() + ": Attempted to add a null service. Operation skipped.");
    }
  }

  /**
   * The main execution method for this `ServiceThread` (invoked when `Thread.start()` is called).
   * This method orchestrates the lifecycle and execution of its assigned services:
   * 1. **Setup Phase:** Calls `setup()` once for every assigned service. If a service's `setup()`
   *    fails (throws an exception), it's logged, and the service is marked as not running
   *    (by calling `service.stop()`).
   * 2. **Main Execution Loop:** Enters a `while(this.running)` loop. This loop represents the
   *    "tick" or polling cycle of the `ServiceThread`. The frequency of this tick is
   *    controlled by `this.threadLoopDelay`.
   * 3. **Inside Each Tick:**
   *    a. Takes a snapshot of the `assignedServices` list. This allows for safe iteration
   *       even if services are removed concurrently by `removeService()` (though additions
   *       during the tick might be missed until the next tick).
   *    b. Records `currentTimeNanosForTick`, a consistent timestamp from `System.nanoTime()`
   *       used for all service "due" checks within this single tick.
   *    c. For each service in the snapshot:
   *        i. If the service's own `running` flag is `false`, it's skipped.
   *       ii. Calculates if the service is "due" to run by comparing `currentTimeNanosForTick`
   *           with its `lastExecTimeNanos` (from the `serviceLastExecutionNanos` map) and its
   *           own requested `loopDelay` (from `service.getLoopDelay()`).
   *      iii. If the service is due:
   *           - Updates its `lastExecTimeNanos` to `currentTimeNanosForTick` *before* calling `loop()`.
   *           - Calls `service.loop()`.
   *           - Records performance metrics (execution time of `loop()`) or error metrics
   *             (if `loop()` throws an exception). Uncaught exceptions from `service.loop()`
   *             are caught here, logged, and the service's error count is incremented.
   *             If `maxConsecutiveErrorsThreshold` is reached, `service.stop()` is called.
   * 4. **Delay:** After checking all services in the current tick, `delay(this.threadLoopDelay)`
   *    is called, pausing the `ServiceThread` until its next polling cycle. The effective
   *    granularity of service execution (how closely their `loopDelay` is honored) is
   *    influenced by this `threadLoopDelay`. For example, a service with a 10ms `loopDelay`
   *    cannot run more frequently than this `ServiceThread`'s `threadLoopDelay`.
   */
  @Override
    public void run() {
    println(getName() + ": Starting. Performing initial setup for " + assignedServices.size() + " assigned services...");

    // --- 1. Setup Phase for all assigned services ---
    // Iterate over a copy of the list for safety, in case a service's setup method
    // were to (improperly) try to modify the ServiceThread's list of services.
    for (BaseService service : new ArrayList<BaseService>(assignedServices)) {
      try {
        if (service.running) { // Only attempt setup if the service hasn't been stopped already.
          println(getName() + ": Setting up service: " + service.getClass().getSimpleName());
          service.setup(); // `BaseService.run()` used to call this; now `ServiceThread` does directly.
          println(getName() + ": Service " + service.getClass().getSimpleName() + " setup complete.");
        } else {
          println(getName() + ": Service " + service.getClass().getSimpleName() +
            " was already marked as not running before setup. Skipping setup.");
        }
      }
      catch (Exception e) {
        // Log the setup failure and mark the service as not running to prevent loop execution.
        println(getName() + ": CRITICAL - Exception during setup for service " +
          service.getClass().getSimpleName() + ": " + e.getMessage());
        e.printStackTrace(); // Essential for debugging setup issues.
        service.stop(); // Mark service as not running if its setup failed.
        // The ServiceScheduler's cleanupCompletedServices will eventually remove it.
      }
    }
    println(getName() + ": All service setups attempted. Starting main execution loop with a thread delay of " + threadLoopDelay + "ms.");

    // --- 2. Main Execution Loop ---
    while (this.running) {
      // Create a snapshot of the services list for this tick. This allows services to be
      // removed from `assignedServices` (by another thread, e.g., ServiceScheduler calling removeService)
      // without causing a ConcurrentModificationException during this iteration.
      // Note: Services added to `assignedServices` *during* this loop's iteration might not be
      // processed until the next tick's snapshot.
      List<BaseService> servicesSnapshot = new ArrayList<>(this.assignedServices);

      // Use a consistent timestamp for all checks within this single tick.
      long currentTimeNanosForTick = System.nanoTime();

      for (BaseService service : servicesSnapshot) {
        // Skip the service if its own 'running' flag is false.
        if (!service.running) {
          // This is verbose for regular operation, uncomment for debugging service states.
          // println(getName() + ": Skipping " + service.getClass().getSimpleName() + " as its 'running' flag is false.");
          continue;
        }

        // Determine if the service is due to run based on its loopDelay.
        long lastExecTimeNanos = this.serviceLastExecutionNanos.getOrDefault(service, 0L);
        long requiredDelayNanos = (long)service.getLoopDelay() * 1_000_000L; // Convert service's ms delay to ns.

        boolean isDue = (currentTimeNanosForTick - lastExecTimeNanos) >= requiredDelayNanos;

        if (isDue) {
          // Update last execution time *before* calling loop() to ensure it's recorded even if loop() fails.
          this.serviceLastExecutionNanos.put(service, currentTimeNanosForTick);

          ServiceMetrics metrics = this.serviceMetricsMap.get(service);
          long metricsStartTimeNanos = System.nanoTime(); // For precise timing of the loop() execution.

          try {
            service.loop(); // Execute the service's main logic.

            // Record successful execution time if metrics are enabled for this service.
            if (metrics != null) {
              long durationNanos = System.nanoTime() - metricsStartTimeNanos;
              metrics.recordLoopTime(durationNanos);
            }
          }
          catch (Exception e) {
            // An uncaught exception occurred within the service's loop() method.
            // Log the error and update error metrics.
            // Using System.err for errors to make them stand out, consistent with e.printStackTrace().
            System.err.println(getName() + ": ERROR encountered in service " +
              service.getClass().getSimpleName() + " during loop(): " + e.getMessage());
            e.printStackTrace(System.err); // Print stack trace for detailed debugging.

            if (metrics != null) {
              metrics.incrementErrorCount();
              // Implement auto-stop logic based on consecutive errors.
              if (metrics.getConsecutiveErrorCount() >= this.maxConsecutiveErrorsThreshold) {
                System.err.println(getName() + ": Service " + service.getClass().getSimpleName() +
                  " has reached the maximum consecutive error threshold of " + this.maxConsecutiveErrorsThreshold +
                  ". Stopping the service automatically to prevent further issues.");
                service.stop(); // Signal the service to stop.
                // It will be cleaned up by ServiceScheduler during its next cleanupCompletedServices run.
                // The consecutiveErrorCount will be reset if the service is ever restarted (new metrics object)
                // or if a successful loop occurs (metrics.recordLoopTime resets it).
              }
            }
            // Note: The decision for a service to stop on *any* single error can also be implemented
            // within the service's own loop() method by catching exceptions and calling `this.stop()` itself.
            // This ServiceThread's auto-stop is a safety net for repeated, unhandled errors.
          }
        }
      }

      // Pause this ServiceThread until its next polling cycle.
      try {
        // The `delay()` function in Processing is typically `Thread.sleep()`.
        // Consider replacing with `Thread.sleep(this.threadLoopDelay);` for clarity if not in a PApplet context.
        delay(this.threadLoopDelay);
      }
      catch (Exception e) { // Catching generic Exception as `delay()` might throw various things.
        // `Thread.sleep` throws `InterruptedException`.
        System.err.println(getName() + ": Delay was interrupted: " + e.getMessage());
        if (!this.running) {
          // If the thread was stopped (e.g., by stopThread()) while sleeping, exit the loop.
          println(getName() + ": Thread was signaled to stop during delay. Exiting main loop.");
          break;
        }
        // If interrupted for other reasons, the loop continues if `this.running` is still true.
      }
    }
    println(getName() + ": Execution loop finished. Thread is terminating.");
  }

  /**
   * Signals a specific service to stop, performs its `cleanup()`, and removes it from this
   * `ServiceThread`'s management. This involves removing it from the `assignedServices` list,
   * its `serviceMetricsMap` entry, and its `serviceLastExecutionNanos` entry.
   * This method is typically called by the `ServiceScheduler` during its cleanup phase.
   *
   * @param service The `BaseService` instance to remove. If null or not found, the method logs and returns.
   */
  public void removeService(BaseService service) { // Made public for ServiceScheduler access
    if (service == null) {
      println(getName() + ": Attempted to remove a null service. Operation aborted.");
      return;
    }

    // Check if the service is actually managed by this thread.
    // Note: `ArrayList.contains()` and `remove()` are O(N) operations.
    // If performance with many services per thread becomes an issue, consider using a Set or Map
    // for `assignedServices` or optimizing removal. For typical use cases, ArrayList is often sufficient.
    if (this.assignedServices.contains(service)) {
      String serviceName = service.getClass().getSimpleName();
      println(getName() + ": Removing service: " + serviceName);

      // Step 1: Signal the service to stop its own operations.
      try {
        println(getName() + ": Attempting to call stop() on service " + serviceName);
        service.stop();
        println(getName() + ": Service " + serviceName + " stop() method successfully called.");
      }
      catch (Exception e) {
        println(getName() + ": Exception during service.stop() for " + serviceName + ": " + e.getMessage());
        e.printStackTrace(System.err); // Log stack trace for debugging.
      }

      // Step 2: Allow the service to release its resources via cleanup().
      try {
        println(getName() + ": Attempting to call cleanup() on service " + serviceName);
        service.cleanup();
        println(getName() + ": Service " + serviceName + " cleanup() method successfully called.");
      }
      catch (Exception e) {
        println(getName() + ": Exception during service.cleanup() for " + serviceName + ": " + e.getMessage());
        e.printStackTrace(System.err); // Log stack trace for debugging.
      }

      // Step 3: Remove the service from this thread's tracking collections.
      // The run() loop iterates a snapshot of assignedServices, so direct removal here is
      // generally safe for the list's consistency in the *next* tick's snapshot.
      // HashMap removals are also generally safe if this method is called by a single external manager (ServiceScheduler).
      boolean removedFromList = this.assignedServices.remove(service);
      this.serviceMetricsMap.remove(service);          // Remove its metrics.
      this.serviceLastExecutionNanos.remove(service);  // Remove its last execution time record.

      if (removedFromList) {
        println(getName() + ": Service " + serviceName +
          " fully removed from thread's tracking. Services remaining: " + assignedServices.size());
      } else {
        // This might occur if removeService is called multiple times for the same service,
        // or if there's a logic issue elsewhere.
        println(getName() + ": Warning - Service " + serviceName +
          " was not found in assignedServices list during final removal step, though it was initially contained.");
      }
    } else {
      println(getName() + ": Service " + service.getClass().getSimpleName() +
        " not found in this thread's assigned list. Removal skipped.");
    }
  }

  /**
   * Returns a new list containing the services currently assigned to this `ServiceThread`.
   * This provides a snapshot of the services managed by this thread.
   * The returned collection is a copy, so modifications to it will not affect the
   * `ServiceThread`'s internal list of services.
   *
   * @return A `Collection<BaseService>` (specifically, an `ArrayList`) of assigned services.
   *         Returns an empty list if no services are currently assigned.
   */
  public Collection<BaseService> getAssignedServices() {
    // Return a new ArrayList copy to prevent external modification of the internal list
    // and to provide a stable collection if the caller iterates over it while this thread might modify its own list.
    return new ArrayList<BaseService>(this.assignedServices);
  }

  /**
   * Returns an unmodifiable view of the map storing `ServiceMetrics` for each service
   * managed by this thread. This allows external classes (like `ServiceScheduler` or `DebugMonitor`)
   * to inspect service metrics safely without being able to modify the map or its contents.
   *
   * @return An unmodifiable `Map` of `BaseService` instances to their `ServiceMetrics`.
   *         Returns an empty map if no services have metrics tracked.
   */
  public Map<BaseService, ServiceMetrics> getServiceMetricsMap() {
    // Return a new HashMap copy wrapped in Collections.unmodifiableMap for robust safety.
    // This prevents external modification of the internal map and its ServiceMetrics objects
    // (if ServiceMetrics were mutable in a way that's problematic).
    return Collections.unmodifiableMap(new HashMap<>(this.serviceMetricsMap));
  }

  /**
   * Signals this `ServiceThread` to stop its main execution loop.
   * The loop, which calls `service.loop()`, will terminate after the current iteration (tick) completes.
   * This is the primary method for gracefully shutting down the `ServiceThread`.
   */
  public void stopThread() {
    println(getName() + ": stopThread() called. Signaling thread to terminate its execution loop.");
    this.running = false;
    // Optional: Interrupt the thread if it's currently sleeping in delay().
    // Standard Thread.sleep() is interruptible. The Processing `delay()` function, if it wraps
    // Thread.sleep(), should also be interruptible. Interrupting can make the thread shut down faster
    // if it's in a long delay. However, ensure that InterruptedException is handled gracefully
    // in the run loop's delay call if you enable this.
    // this.interrupt();
  }

  /**
   * Gets the configured polling interval (loop delay) for this `ServiceThread` itself.
   * This is the duration, in milliseconds, that the thread pauses between its ticks.
   *
   * @return The thread's loop delay in milliseconds.
   */
  public int getThreadLoopDelay() {
    return threadLoopDelay;
  }

  /**
   * Sets the polling interval (loop delay) for this `ServiceThread`.
   *
   * @param delayMs The delay in milliseconds. Must be a positive value.
   *                If non-positive, an error is logged, and the delay is not changed.
   */
  public void setThreadLoopDelay(int delayMs) {
    if (delayMs > 0) {
      this.threadLoopDelay = delayMs;
      println(getName() + ": Thread loop delay set to " + delayMs + "ms.");
    } else {
      println(getName() + ": Invalid thread loop delay: " + delayMs +
        "ms. Must be positive. Keeping current: " + this.threadLoopDelay + "ms.");
    }
  }

  /**
   * Gets the configured maximum consecutive error threshold. This is the number of times
   * a service's `loop()` can fail consecutively before this thread automatically stops it.
   *
   * @return The threshold count.
   */
  public int getMaxConsecutiveErrorsThreshold() {
    return this.maxConsecutiveErrorsThreshold;
  }

  /**
   * Sets the maximum consecutive error threshold for automatically stopping services.
   *
   * @param threshold The number of consecutive `loop()` errors before a service is stopped.
   *                  Must be greater than 0. If non-positive, an error is logged,
   *                  and the threshold is not changed.
   */
  public void setMaxConsecutiveErrorsThreshold(int threshold) {
    if (threshold > 0) {
      this.maxConsecutiveErrorsThreshold = threshold;
      println(getName() + ": Max consecutive errors threshold set to " + threshold);
    } else {
      println(getName() + ": Invalid max consecutive errors threshold: " + threshold +
        ". Must be > 0. Keeping current: " + this.maxConsecutiveErrorsThreshold);
    }
  }
}
